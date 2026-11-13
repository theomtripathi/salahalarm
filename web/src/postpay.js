// What happens after a web payment (salahalarm.com/start/paid/):
//   - a seat in the Ramadan 2027 Free Makkah Trip draw for paying (users/{uid}.challengeSeats.paid)
//   - one more seat for sharing their link (challengeSeats.shared)
//   - iPhone buyers: Pro granted in RevenueCat to the same Firebase uid, so the iOS
//     app unlocks when they sign in with the same account
//   - purchases reported to the affiliate Worker (service binding AFFILIATES)
//
// Seat rules shown to buyers (Om left them to us, 13 Nov 2026):
//   paid 1 · shared your link +1 (once) · each friend who joins with your link +1 (up to 50)
//   · logging all five prayers for 30 / 60 / 90 full days +1 / +2 / +3 (the published draw rules).

import { joinChallenge, readChallenge, joiningOpen } from "./challenge.js";
import { isActive } from "./entitlement.js";

export const FRIEND_SEAT_CAP = 50;

/** Seats as the post-payment page shows them. `logged` comes from the apps and is not known here. */
export function seatSummary({ paid = false, shared = false, friends = 0 } = {}) {
  const seats = {
    paid: paid ? 1 : 0,
    shared: shared ? 1 : 0,
    friends: Math.min(FRIEND_SEAT_CAP, Math.max(0, Number(friends) || 0)),
  };
  return { seats, total: seats.paid + seats.shared + seats.friends };
}

export function isPaid(ent, now = Date.now()) {
  return Boolean(ent && ent.provider === "dodo" && isActive(ent, now));
}

/**
 * Makes sure a paying account is in the challenge with its paid seat. Idempotent.
 * Returns { challenge, seats, total, created, granted }.
 */
export async function ensurePaidSeat(db, uid, { invite, now = new Date() } = {}) {
  const [ent, profile] = await Promise.all([db.get(`entitlements/${uid}`), db.get(`users/${uid}`)]);
  const paid = isPaid(ent, now.getTime());
  let challenge = profile?.challenge?.code ? await readChallenge(db, uid) : null;
  let created = false;
  if (paid && !challenge && joiningOpen(now.getTime())) {
    ({ challenge, created } = await joinChallenge(db, uid, { invite: invite || profile?.webInvite, now }));
  }
  const current = profile?.challengeSeats || {};
  let granted = false;
  if (paid && challenge && !current.paid) {
    await db.merge(`users/${uid}`, { challengeSeats: { ...current, paid: 1, paidAt: now } });
    current.paid = 1;
    granted = true;
  }
  const friends = challenge?.code ? (await db.get(`referrals/${challenge.code}`).catch(() => null))?.joinedCount || 0 : 0;
  return { challenge, created, granted, paid, ...seatSummary({ paid: Boolean(current.paid), shared: Boolean(current.shared), friends }) };
}

/** +1 seat for sharing the invite link, counted once. */
export async function grantShareSeat(db, uid, { method = "share", now = new Date() } = {}) {
  const profile = await db.get(`users/${uid}`);
  const current = profile?.challengeSeats || {};
  if (!profile?.challenge?.code) return { granted: false, reason: "not in the challenge" };
  if (current.shared) return { granted: false, reason: "already counted" };
  await db.merge(`users/${uid}`, { challengeSeats: { ...current, shared: 1, sharedAt: now, sharedVia: String(method).slice(0, 20) } });
  return { granted: true };
}

// ---- RevenueCat --------------------------------------------------------------

const RC = "https://api.revenuecat.com/v1";
const DAY = 24 * 60 * 60 * 1000;

/**
 * Grants the RevenueCat entitlement to the Firebase uid until the web plan's paid
 * period ends (plus a day), so the iOS app (which logs RevenueCat in with the same
 * uid) opens unlocked. Called again on every renewal, which moves the end date.
 */
export async function grantRevenueCat(env, uid, ent, { affiliate, fetchImpl = fetch, now = Date.now() } = {}) {
  const key = env.REVENUECAT_SECRET_KEY;
  if (!key) return { skipped: "no REVENUECAT_SECRET_KEY" };
  const entitlement = env.REVENUECAT_ENTITLEMENT || "sonn apps Pro";
  const until = Date.parse(ent?.accessUntil || "") || now + (ent?.plan === "yearly" ? 366 : 8) * DAY;
  const endTime = Math.max(until, now + DAY) + DAY;
  const headers = { authorization: `Bearer ${key}`, "content-type": "application/json" };
  const id = encodeURIComponent(uid);
  const res = await fetchImpl(`${RC}/subscribers/${id}/entitlements/${encodeURIComponent(entitlement)}/promotional`, {
    method: "POST",
    headers,
    body: JSON.stringify({ end_time_ms: endTime }),
  });
  const out = { status: res.status, ok: res.ok, endTime };
  if (!res.ok) out.error = (await res.text().catch(() => "")).slice(0, 300);
  const attributes = { web_plan: { value: ent?.plan || "" }, web_paid_until: { value: new Date(endTime).toISOString() } };
  if (ent?.email) attributes.$email = { value: ent.email };
  if (affiliate) attributes.affiliate = { value: affiliate };
  await fetchImpl(`${RC}/subscribers/${id}/attributes`, { method: "POST", headers, body: JSON.stringify({ attributes }) }).catch(() => {});
  return out;
}

// ---- Affiliates ----------------------------------------------------------------

export function intervalOf(plan) {
  if (plan === "yearly") return "year";
  if (plan === "lifetime") return "lifetime";
  return "week";
}

/** Body for the affiliate Worker's /api/ingest (contract agreed with the affiliate thread). */
export function affiliatePayload(type, { uid, ent, sub, payment }) {
  const minor = typeof sub?.recurring_pre_tax_amount === "number" ? sub.recurring_pre_tax_amount
    : typeof payment?.total_amount === "number" ? payment.total_amount
    : typeof ent?.amount === "number" ? ent.amount : null;
  return {
    type,
    app_user_id: uid || sub?.metadata?.uid || payment?.metadata?.uid || null,
    affiliate: sub?.metadata?.affiliate || payment?.metadata?.affiliate || null,
    platform: sub?.metadata?.platform || payment?.metadata?.platform || "web",
    plan: ent?.plan || sub?.metadata?.plan || null,
    interval: intervalOf(ent?.plan || sub?.metadata?.plan),
    product_id: sub?.product_id || ent?.productId || null,
    amount: minor == null ? null : Math.round(minor) / 100,
    currency: sub?.currency || payment?.currency || ent?.currency || null,
    dodo_payment_id: payment?.payment_id || null,
    subscription_id: sub?.subscription_id || payment?.subscription_id || null,
  };
}

export async function notifyAffiliates(env, payload) {
  if (!env.AFFILIATES?.fetch) return { skipped: "no AFFILIATES binding" };
  const res = await env.AFFILIATES.fetch("https://aff.internal/api/ingest", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  return { status: res.status };
}
