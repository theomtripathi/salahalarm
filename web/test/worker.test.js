import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import worker, { handleEvent, preferredLang } from "../src/worker.js";
import { signWebhook, verifyWebhook } from "../src/dodo.js";
import { tierFor, productFor, displayPlans } from "../src/pricing.js";
import { entitlementFromSubscription, shouldReplace, accessUntilFor } from "../src/entitlement.js";
import { scheduleFor, methodFor, madhabFor } from "../src/prayer.js";
import { verifyIdToken, resetKeyCache } from "../src/auth.js";
import { resetTokenCache } from "../src/firestore.js";
import { createBackend, env, ctx, request, idToken, PROJECT } from "./fakes.js";

let backend;
beforeEach(() => {
  backend = createBackend();
  globalThis.fetch = backend.fetch;
  resetKeyCache();
  resetTokenCache();
});

const call = async (path, opts) => {
  const res = await worker.fetch(request(path, opts), opts?.env || env(), ctx);
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null, headers: res.headers };
};

// ---- pricing ---------------------------------------------------------------

test("countries map to price tiers, unknown countries to the middle tier", () => {
  assert.equal(tierFor("US"), "t1");
  assert.equal(tierFor("ae"), "t1");
  assert.equal(tierFor("SA"), "t2");
  assert.equal(tierFor("ID"), "t3");
  assert.equal(tierFor("IN"), "t3");
  assert.equal(tierFor("PK"), "t3");
  assert.equal(tierFor("NG"), "t3");
  assert.equal(tierFor("ZZ"), "t2");
  assert.equal(tierFor(null), "t2");
});

test("a tier without products falls back to t2 then t1", () => {
  assert.deepEqual(productFor({ t2: { yearly: "y2" } }, "t3", "yearly"), { tier: "t2", productId: "y2" });
  assert.deepEqual(productFor({ t1: { monthly: "m1" } }, "t3", "monthly"), { tier: "t1", productId: "m1" });
  assert.equal(productFor({}, "t3", "monthly"), null);
});

test("display plans put yearly first with a monthly equivalent", () => {
  const plans = displayPlans("t3", { trialDays: { yearly: 3 } });
  assert.equal(plans[0].plan, "yearly");
  assert.equal(plans[0].amount, 9.99);
  assert.equal(plans[0].monthlyEquivalent, 0.83);
  assert.equal(plans[0].trialDays, 3);
  assert.equal(plans[1].plan, "monthly");
});

// ---- auth ------------------------------------------------------------------

test("valid Firebase ID tokens verify; bad ones are rejected", async () => {
  const u = await verifyIdToken(idToken(), PROJECT);
  assert.equal(u.uid, "user-1");
  assert.equal(u.email, "amina@example.com");
  await assert.rejects(verifyIdToken(idToken({ project: "other" }), PROJECT), /audience/);
  await assert.rejects(verifyIdToken(idToken({ expOffset: -4000 }), PROJECT), /expired/);
  await assert.rejects(verifyIdToken(idToken({ kid: "nope" }), PROJECT), /unknown signing key/);
  const t = idToken();
  const tampered = t.split(".");
  tampered[1] = Buffer.from(JSON.stringify({ sub: "attacker", aud: PROJECT })).toString("base64url");
  await assert.rejects(verifyIdToken(tampered.join("."), PROJECT), /signature/);
});

test("API calls without a token get 401", async () => {
  const r = await call("/api/entitlement");
  assert.equal(r.status, 401);
});

// ---- config ----------------------------------------------------------------

test("config returns tier, local prices and today's prayer times for the visitor", async () => {
  backend.dodo.previewCurrency = { currency: "IDR", amount: 15900000 };
  const r = await call("/api/config", { country: "ID", headers: { "accept-language": "id-ID,id;q=0.9" } });
  assert.equal(r.status, 200);
  assert.equal(r.body.tier, "t3");
  assert.equal(r.body.lang, "id");
  assert.equal(r.body.geo.city, "Jakarta");
  assert.equal(r.body.plans[0].currency, "IDR");
  assert.equal(r.body.plans[0].amount, 159000);
  assert.equal(r.body.schedule.method, "Singapore");
  assert.ok(Date.parse(r.body.schedule.times.fajr) < Date.parse(r.body.schedule.times.dhuhr));
  assert.equal(r.body.firebase.projectId, PROJECT);
});

test("config falls back to USD list prices when the preview fails", async () => {
  const r = await call("/api/config", { country: "IN" });
  assert.equal(r.body.plans[0].currency, "USD");
  assert.equal(r.body.plans[0].amount, 9.99);
});

test("language comes from the browser first, then the country", () => {
  assert.equal(preferredLang("ar-SA,ar;q=0.9", "SA"), "ar");
  assert.equal(preferredLang("en-US,en;q=0.9", "ID"), "en");
  assert.equal(preferredLang("in-ID", "ID"), "id");
  assert.equal(preferredLang("ms-MY", "TR"), "tr");
  assert.equal(preferredLang("", "PK"), "en");
});

// ---- prayer times ------------------------------------------------------------

test("prayer methods follow the country", () => {
  assert.equal(methodFor("SA"), "UmmAlQura");
  assert.equal(methodFor("PK"), "Karachi");
  assert.equal(madhabFor("PK"), "hanafi");
  assert.equal(madhabFor("ID"), "shafi");
  assert.equal(methodFor("FR"), "MuslimWorldLeague");
  const s = scheduleFor({ latitude: 21.4225, longitude: 39.8262, country: "SA", timezone: "Asia/Riyadh", now: new Date("2026-10-25T00:00:00Z") });
  const fajr = new Date(s.times.fajr);
  // Makkah Fajr in late October is around 05:00 local (02:00 UTC)
  assert.ok(fajr.getUTCHours() >= 1 && fajr.getUTCHours() <= 3, s.times.fajr);
});

// ---- checkout → entitlement ------------------------------------------------

test("checkout creates a Dodo session for the visitor's tier with the uid in metadata", async () => {
  const r = await call("/api/checkout", { method: "POST", token: idToken(), body: { plan: "monthly", lang: "id", ref: "tt03" }, country: "ID" });
  assert.equal(r.status, 200);
  assert.match(r.body.checkoutUrl, /checkout\.dodopayments\.com/);
  const req = backend.dodo.created[0];
  assert.equal(req.product_cart[0].product_id, "pdt_t3_m");
  assert.equal(req.metadata.uid, "user-1");
  assert.equal(req.metadata.ref, "tt03");
  assert.equal(req.customer.email, "amina@example.com");
  assert.equal(req.return_url, "https://salahalarm.com/android/welcome/?plan=monthly");
  assert.equal(req.customization.force_language, "id");
  assert.equal(backend.docs.get("users/user-1").lastWebCheckout.sessionId, r.body.sessionId);
});

test("a trial configured in TRIAL_DAYS is passed to Dodo", async () => {
  await call("/api/checkout", { method: "POST", token: idToken(), body: { plan: "yearly" }, env: env({ TRIAL_DAYS: '{"yearly":3}' }) });
  assert.equal(backend.dodo.created[0].subscription_data.trial_period_days, 3);
});

test("after paying, entitlement is confirmed with Dodo even before the webhook arrives", async () => {
  const token = idToken();
  const c = await call("/api/checkout", { method: "POST", token, body: { plan: "yearly" } });
  let r = await call("/api/entitlement", { token });
  assert.equal(r.body.entitlement.active, false);

  backend.pay(c.body.sessionId);
  r = await call("/api/entitlement", { token });
  assert.equal(r.body.entitlement.active, true);
  assert.equal(r.body.entitlement.plan, "yearly");
  assert.equal(backend.docs.get("entitlements/user-1").subscriptionId, `sub_${c.body.sessionId}`);

  // A second checkout attempt short-circuits
  const again = await call("/api/checkout", { method: "POST", token, body: { plan: "monthly" } });
  assert.equal(again.body.alreadyActive, true);
});

test("someone else's subscription id does not unlock an account", async () => {
  const c = await call("/api/checkout", { method: "POST", token: idToken({ uid: "owner", email: "owner@example.com" }), body: { plan: "yearly" } });
  const sub = backend.pay(c.body.sessionId);
  const r = await call(`/api/entitlement?subscription_id=${sub.subscription_id}`, { token: idToken({ uid: "thief", email: "thief@example.com" }) });
  assert.equal(r.body.entitlement.active, false);
});

// ---- webhooks --------------------------------------------------------------

async function sendWebhook(event, { secret = env().DODO_WEBHOOK_SECRET, timestamp = Math.floor(Date.now() / 1000) } = {}) {
  const body = JSON.stringify(event);
  const id = `msg_${Math.random().toString(36).slice(2)}`;
  const signature = await signWebhook(secret, id, String(timestamp), body);
  return call("/api/webhooks/dodo", {
    method: "POST",
    body,
    headers: { "webhook-id": id, "webhook-timestamp": String(timestamp), "webhook-signature": signature },
  });
}

const sub = (overrides = {}) => ({
  subscription_id: "sub_1",
  status: "active",
  product_id: "pdt_t3_y",
  customer: { customer_id: "cus_9", email: "Amina@Example.com" },
  metadata: { uid: "user-1", plan: "yearly", tier: "t3", country: "ID", ref: "tt03" },
  next_billing_date: new Date(Date.now() + 365 * 864e5).toISOString(),
  payment_frequency_interval: "Year",
  cancel_at_next_billing_date: false,
  ...overrides,
});

test("signed webhooks grant and revoke access; unsigned ones are refused", async () => {
  let r = await sendWebhook({ type: "subscription.active", timestamp: new Date().toISOString(), data: sub() });
  assert.equal(r.status, 200);
  assert.equal(backend.docs.get("entitlements/user-1").active, true);
  assert.equal(backend.docs.get("entitlements/user-1").email, "amina@example.com");

  r = await sendWebhook({ type: "subscription.on_hold", timestamp: new Date(Date.now() + 1000).toISOString(), data: sub({ status: "on_hold" }) });
  assert.equal(backend.docs.get("entitlements/user-1").active, false);

  r = await sendWebhook({ type: "subscription.active", data: sub() }, { secret: `whsec_${Buffer.from("wrong").toString("base64")}` });
  assert.equal(r.status, 401);
  r = await sendWebhook({ type: "subscription.active", data: sub() }, { timestamp: Math.floor(Date.now() / 1000) - 3600 });
  assert.equal(r.status, 401);
});

test("an older webhook arriving late does not undo a newer one", async () => {
  await sendWebhook({ type: "subscription.cancelled", timestamp: "2026-10-25T10:00:00Z", data: sub({ status: "cancelled" }) });
  await sendWebhook({ type: "subscription.active", timestamp: "2026-10-25T09:00:00Z", data: sub() });
  assert.equal(backend.docs.get("entitlements/user-1").status, "cancelled");
});

test("a purchase without a uid is parked by email and claimed at sign-in", async () => {
  await sendWebhook({ type: "subscription.active", data: sub({ metadata: {}, customer: { customer_id: "cus_2", email: "Bilal@Example.com" } }) });
  assert.equal(backend.docs.get("pendingEntitlements/bilal@example.com").active, true);
  const r = await call("/api/entitlement", { token: idToken({ uid: "bilal", email: "bilal@example.com" }), env: env({ DODO_PAYMENTS_API_KEY: "" }) });
  assert.equal(r.body.entitlement.active, true);
  assert.equal(backend.docs.has("pendingEntitlements/bilal@example.com"), false);
  assert.equal(backend.docs.get("entitlements/bilal").customerId, "cus_2");
});

test("unverified emails cannot claim parked purchases", async () => {
  await handleEvent(env(), {
    get: async (p) => backend.docs.get(p) || null,
    merge: async (p, d) => backend.docs.set(p, { ...(backend.docs.get(p) || {}), ...d }),
  }, { type: "subscription.active", data: sub({ metadata: {}, customer: { customer_id: "c", email: "x@example.com" } }) });
  const r = await call("/api/entitlement", { token: idToken({ uid: "x", email: "x@example.com", verified: false }), env: env({ DODO_PAYMENTS_API_KEY: "" }) });
  assert.equal(r.body.entitlement.active, false);
});

test("webhook verification follows Standard Webhooks", async () => {
  const secret = `whsec_${Buffer.from("k").toString("base64")}`;
  const sig = await signWebhook(secret, "msg_1", "1700000000", "{}");
  const headers = new Headers({ "webhook-id": "msg_1", "webhook-timestamp": "1700000000", "webhook-signature": `v1,bogus ${sig}` });
  await verifyWebhook(secret, headers, "{}", { now: 1700000000 * 1000 });
  await assert.rejects(verifyWebhook(secret, headers, "{ }", { now: 1700000000 * 1000 }), /signature/);
});

// ---- entitlement rules -----------------------------------------------------

test("access windows: grace after renewal date, scheduled cancel keeps the paid period", () => {
  const now = Date.parse("2026-10-25T00:00:00Z");
  assert.equal(accessUntilFor({ status: "active", next_billing_date: "2026-11-25T00:00:00Z" }, now), "2026-11-27T00:00:00.000Z");
  assert.equal(accessUntilFor({ status: "past_due", next_billing_date: "2026-10-24T00:00:00Z" }, now), "2026-10-27T00:00:00.000Z");
  assert.equal(accessUntilFor({ status: "cancelled", cancel_at_next_billing_date: true, next_billing_date: "2026-11-01T00:00:00Z" }, now), "2026-11-01T00:00:00Z");
  assert.equal(Date.parse(accessUntilFor({ status: "expired" }, now)), now);
  const e = entitlementFromSubscription({ ...sub(), status: "active" }, { now });
  assert.equal(e.plan, "yearly");
  assert.equal(e.active, true);
});

test("a second subscription only replaces the first when it lasts longer", () => {
  const current = { subscriptionId: "a", accessUntil: "2027-10-01T00:00:00Z", lastEventAt: "2026-10-01T00:00:00Z" };
  assert.equal(shouldReplace(current, { subscriptionId: "b", accessUntil: "2026-11-01T00:00:00Z", lastEventAt: "2026-10-20T00:00:00Z" }), false);
  assert.equal(shouldReplace(current, { subscriptionId: "b", accessUntil: "2028-01-01T00:00:00Z", lastEventAt: "2026-10-20T00:00:00Z" }), true);
});

// ---- profile, portal --------------------------------------------------------

test("onboarding answers are saved in the iOS format", async () => {
  const r = await call("/api/profile", {
    method: "POST",
    token: idToken(),
    body: { profile: { selectedAlarmPrayers: ["fajr", "isha", "bogus"], goals: ["fajrMornings", "x"], commitmentLevel: "committed", alarmStrictness: "moderate" } },
  });
  assert.equal(r.status, 200);
  const doc = backend.docs.get("users/user-1");
  assert.deepEqual(doc.onboardingProfile.selectedAlarmPrayers, ["fajr", "isha"]);
  assert.deepEqual(doc.onboardingProfile.goals, ["fajrMornings"]);
  assert.equal(doc.onboardingProfile.alarmStrictness, "moderate");
  assert.equal(doc.onboardingPlatform, "android_web");
});

test("portal returns a Dodo link for web subscribers only", async () => {
  let r = await call("/api/portal", { method: "POST", token: idToken() });
  assert.equal(r.status, 404);
  await sendWebhook({ type: "subscription.active", data: sub() });
  r = await call("/api/portal", { method: "POST", token: idToken() });
  assert.equal(r.body.url, "https://test.customer.dodopayments.com/cus_9");
});

test("APK download streams from R2 with the Android package type", async () => {
  const bytes = new Uint8Array([80, 75, 3, 4]);
  const APKS = {
    get: async (key) => (key === "salahalarm-latest.apk" ? { body: new Blob([bytes]).stream(), size: 4, httpEtag: '"e"' } : key === "latest.json" ? { json: async () => ({ versionCode: 3, versionName: "1.0.2" }) } : null),
    head: async () => ({ size: 4 }),
  };
  const res = await worker.fetch(request("/download/salahalarm.apk"), env({ APKS }), ctx);
  assert.equal(res.headers.get("content-type"), "application/vnd.android.package-archive");
  assert.match(res.headers.get("content-disposition"), /SalahAlarm\.apk/);
  assert.equal((await res.arrayBuffer()).byteLength, 4);
  const latest = await worker.fetch(request("/api/android/latest"), env({ APKS }), ctx);
  assert.deepEqual(await latest.json(), { versionCode: 3, versionName: "1.0.2", url: "/download/salahalarm.apk" });
});
