// The 90-Day Ramadan Ready challenge (#ImRamadanReady), server side.
// Same Firestore layout as the iOS app (ChallengeService.swift):
//   users/<uid>.challenge   = { joinedAt, code, invitedBy }
//   referrals/<CODE>        = { ownerUid, createdAt, joinedCount }
//   challengeStats/global   = { joinedCount }
// Joining is free. Android and web joiners are written here with the service
// account, so they don't depend on the client Firestore rules.

export const CODE_LENGTH = 6;
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

export function normalizeCode(raw) {
  const code = String(raw ?? "").trim().toUpperCase();
  if (code.length !== CODE_LENGTH) return null;
  for (const ch of code) if (!ALPHABET.includes(ch)) return null;
  return code;
}

export function randomCode(random = () => crypto.getRandomValues(new Uint32Array(1))[0] / 2 ** 32) {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) out += ALPHABET[Math.floor(random() * ALPHABET.length)];
  return out;
}

export function publicChallenge(c) {
  if (!c?.code) return null;
  return { code: c.code, joinedAt: c.joinedAt || null, invitedBy: c.invitedBy || null };
}

export async function readChallenge(db, uid) {
  return publicChallenge((await db.get(`users/${uid}`))?.challenge);
}

/** Joins `uid` (idempotent). Returns { challenge, created }. */
export async function joinChallenge(db, uid, { invite, now = new Date(), random } = {}) {
  const existing = await readChallenge(db, uid);
  if (existing) return { challenge: existing, created: false };

  let code = null;
  for (let i = 0; i < 6 && !code; i++) {
    const candidate = randomCode(random);
    if (await db.create(`referrals/${candidate}`, { ownerUid: uid, createdAt: now, joinedCount: 0 })) code = candidate;
  }
  if (!code) throw new Error("couldn't allocate an invite code");

  let invitedBy = normalizeCode(invite);
  if (invitedBy === code) invitedBy = null;
  // Only count codes that belong to someone else.
  if (invitedBy) {
    const ref = await db.get(`referrals/${invitedBy}`);
    if (!ref || ref.ownerUid === uid) invitedBy = null;
  }

  const challenge = { joinedAt: now, code, ...(invitedBy && { invitedBy }) };
  await db.merge(`users/${uid}`, { challenge });
  await Promise.allSettled([
    db.increment("challengeStats/global", "joinedCount"),
    invitedBy ? db.increment(`referrals/${invitedBy}`, "joinedCount") : null,
  ]);
  return { challenge: publicChallenge({ ...challenge, joinedAt: now.toISOString() }), created: true };
}

export async function challengeCounts(db, code) {
  const [stats, ref] = await Promise.all([
    db.get("challengeStats/global").catch(() => null),
    code ? db.get(`referrals/${code}`).catch(() => null) : null,
  ]);
  return { joinedCount: stats?.joinedCount ?? null, friendsJoined: ref?.joinedCount ?? 0 };
}
