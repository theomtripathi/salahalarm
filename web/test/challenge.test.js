import { test } from "node:test";
import assert from "node:assert/strict";
import { joinChallenge, normalizeCode, randomCode, challengeCounts } from "../src/challenge.js";

function memoryDb() {
  const docs = new Map();
  return {
    docs,
    async get(p) { return docs.has(p) ? structuredClone(docs.get(p)) : null; },
    async merge(p, d) { docs.set(p, { ...(docs.get(p) || {}), ...d }); },
    async create(p, d) { if (docs.has(p)) return false; docs.set(p, d); return true; },
    async increment(p, f, by = 1) { const d = docs.get(p) || {}; d[f] = (d[f] || 0) + by; docs.set(p, d); },
  };
}

test("codes use the iOS alphabet and length", () => {
  assert.equal(normalizeCode(" abc234 "), "ABC234");
  assert.equal(normalizeCode("ABC10I"), null); // 1, 0, I are not in the alphabet
  assert.equal(normalizeCode("ABC23"), null);
  assert.match(randomCode(), /^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}$/);
});

test("joining creates a code, credits the inviter once, and is idempotent", async () => {
  const db = memoryDb();
  const a = await joinChallenge(db, "alice");
  assert.equal(a.created, true);
  assert.equal(db.docs.get(`referrals/${a.challenge.code}`).ownerUid, "alice");

  const b = await joinChallenge(db, "bob", { invite: a.challenge.code.toLowerCase() });
  assert.equal(b.challenge.invitedBy, a.challenge.code);
  assert.equal(db.docs.get(`referrals/${a.challenge.code}`).joinedCount, 1);
  assert.equal(db.docs.get("challengeStats/global").joinedCount, 2);

  const again = await joinChallenge(db, "bob", { invite: a.challenge.code });
  assert.equal(again.created, false);
  assert.equal(again.challenge.code, b.challenge.code);
  assert.equal(db.docs.get(`referrals/${a.challenge.code}`).joinedCount, 1);

  const counts = await challengeCounts(db, a.challenge.code);
  assert.deepEqual(counts, { joinedCount: 2, friendsJoined: 1 });
});

test("unknown or own invite codes are ignored", async () => {
  const db = memoryDb();
  const c = await joinChallenge(db, "carol", { invite: "ZZZZZZ" });
  assert.equal(c.challenge.invitedBy, null);
});

test("retries when a code is taken", async () => {
  const db = memoryDb();
  db.docs.set("referrals/AAAAAA", { ownerUid: "x" });
  let n = 0;
  const r = await joinChallenge(db, "dave", { random: () => (n++ < 6 ? 0 : 0.5) });
  assert.notEqual(r.challenge.code, "AAAAAA");
});

test("joining closes after 9 January 2027, but existing joiners keep their code", async () => {
  const db = memoryDb();
  const early = await joinChallenge(db, "erin", { now: new Date("2027-01-09T20:00:00Z") });
  assert.equal(early.created, true);
  await assert.rejects(joinChallenge(db, "frank", { now: new Date("2027-01-11T00:00:00Z") }), /closed/);
  const again = await joinChallenge(db, "erin", { now: new Date("2027-01-11T00:00:00Z") });
  assert.equal(again.challenge.code, early.challenge.code);
});
