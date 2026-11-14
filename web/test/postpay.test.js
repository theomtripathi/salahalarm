import { test } from "node:test";
import assert from "node:assert/strict";
import { ensurePaidSeat, grantRevenueCat, affiliatePayload, seatSummary, notifyAffiliates } from "../src/postpay.js";

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
const NOW = new Date("2026-11-14T10:00:00Z");
const paid = { provider: "dodo", active: true, status: "active", plan: "yearly", accessUntil: "2027-11-16T10:00:00Z" };

test("paying joins the buyer to the free challenge once, with no extra entries", async () => {
  const db = memoryDb();
  db.docs.set("entitlements/u1", paid);
  const a = await ensurePaidSeat(db, "u1", { now: NOW });
  assert.equal(a.granted, true);
  assert.equal(a.total, 0);
  assert.equal(a.seats.joined, 1);
  assert.match(a.challenge.code, /^[A-Z2-9]{6}$/);
  const b = await ensurePaidSeat(db, "u1", { now: NOW });
  assert.equal(b.granted, false);
  assert.equal(b.total, 0);
  assert.equal(b.challenge.code, a.challenge.code);
  assert.equal(db.docs.get("challengeStats/global").joinedCount, 1);
});

test("no seat without a paid plan", async () => {
  const db = memoryDb();
  db.docs.set("entitlements/u2", { provider: "trial", active: true, accessUntil: "2027-01-01T00:00:00Z" });
  const r = await ensurePaidSeat(db, "u2", { now: NOW });
  assert.equal(r.paid, false);
  assert.equal(r.total, 0);
  assert.equal(r.challenge, null);
});

test("friends add one entry each, up to 50; sharing alone adds nothing", async () => {
  const db = memoryDb();
  db.docs.set("entitlements/u1", paid);
  const { challenge } = await ensurePaidSeat(db, "u1", { now: NOW });
  db.docs.set(`referrals/${challenge.code}`, { ownerUid: "u1", joinedCount: 3 });
  const r = await ensurePaidSeat(db, "u1", { now: NOW });
  assert.deepEqual(r.seats, { joined: 1, friends: 3 });
  assert.equal(r.total, 3);
  assert.equal(seatSummary({ paid: true, friends: 80 }).seats.friends, 50);
});

test("RevenueCat gets a promotional grant until the paid period ends, under the Firebase uid", async () => {
  const calls = [];
  const fetchImpl = async (url, init) => { calls.push({ url, init }); return new Response("{}", { status: 201 }); };
  const r = await grantRevenueCat({ REVENUECAT_SECRET_KEY: "sk_test", REVENUECAT_ENTITLEMENT: "sonn apps Pro" }, "uid 1", { ...paid, email: "a@b.co" }, { affiliate: "ali", fetchImpl, now: NOW.getTime() });
  assert.equal(r.ok, true);
  assert.equal(calls[0].url, "https://api.revenuecat.com/v1/subscribers/uid%201/entitlements/sonn%20apps%20Pro/promotional");
  assert.equal(calls[0].init.headers.authorization, "Bearer sk_test");
  assert.equal(JSON.parse(calls[0].init.body).end_time_ms, Date.parse(paid.accessUntil) + 86400000);
  const attrs = JSON.parse(calls[1].init.body).attributes;
  assert.equal(attrs.affiliate.value, "ali");
  assert.equal(attrs.$email.value, "a@b.co");
  assert.deepEqual(await grantRevenueCat({}, "u", paid, { fetchImpl }), { skipped: "no REVENUECAT_SECRET_KEY" });
});

test("affiliate reports carry the agreed fields in major units", async () => {
  const sub = { subscription_id: "sub_1", product_id: "pdt_y", currency: "USD", recurring_pre_tax_amount: 4999, metadata: { uid: "u1", affiliate: "ali", plan: "yearly" } };
  const p = affiliatePayload("purchased", { uid: "u1", ent: { plan: "yearly" }, sub });
  assert.deepEqual(p, { type: "purchased", app_user_id: "u1", affiliate: "ali", platform: "web", plan: "yearly", interval: "year", product_id: "pdt_y", amount: 49.99, currency: "USD", dodo_payment_id: null, subscription_id: "sub_1" });
  const seen = [];
  await notifyAffiliates({ AFFILIATES: { fetch: async (url, init) => { seen.push([url, JSON.parse(init.body)]); return new Response("ok"); } } }, p);
  assert.equal(seen[0][0], "https://aff.internal/api/ingest");
  assert.deepEqual(await notifyAffiliates({}, p), { skipped: "no AFFILIATES binding" });
});
