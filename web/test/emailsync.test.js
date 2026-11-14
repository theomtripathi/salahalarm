import { test } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { syncEmails, emailOf, isRecent, FULL_SYNC_CRON } from "../src/emailsync.js";

const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const sa = { client_email: "sync@example.iam.gserviceaccount.com", private_key: privateKey.export({ type: "pkcs8", format: "pem" }) };
const env = { POSTHOG_KEY: "phc_test", POSTHOG_HOST: "https://ph.test", FIREBASE_PROJECT_ID: "proj" };
const NOW = Date.parse("2026-11-14T10:00:00Z");
const ago = (min) => String(NOW - min * 60_000);

const USERS = [
  { localId: "new1", email: "New@Example.com", createdAt: ago(5), lastLoginAt: ago(5) },
  { localId: "back1", email: "back@example.com", createdAt: ago(60 * 24 * 30), lastLoginAt: ago(20) },
  { localId: "old1", email: "old@example.com", createdAt: ago(60 * 24 * 30), lastLoginAt: ago(60 * 24) },
  { localId: "relay", providerUserInfo: [{ providerId: "apple.com", email: "x@privaterelay.appleid.com" }], createdAt: ago(1), lastLoginAt: ago(1) },
  { localId: "anon", createdAt: ago(1), lastLoginAt: ago(1) },
  { localId: "off", email: "off@example.com", disabled: true, createdAt: ago(1), lastLoginAt: ago(1) },
];

function fakeFetch(users, pageSize = 2) {
  const calls = { batches: [], pages: 0 };
  const fn = async (url, init = {}) => {
    const u = String(url);
    if (u === "https://oauth2.googleapis.com/token") return Response.json({ access_token: "tok", expires_in: 3600 });
    if (u.includes("accounts:batchGet")) {
      assert.equal(init.headers.authorization, "Bearer tok");
      const start = Number(new URL(u).searchParams.get("nextPageToken") || 0);
      calls.pages++;
      const next = start + pageSize < users.length ? String(start + pageSize) : undefined;
      return Response.json({ users: users.slice(start, start + pageSize), nextPageToken: next });
    }
    if (u === "https://ph.test/batch/") {
      const body = JSON.parse(init.body);
      assert.equal(body.api_key, "phc_test");
      calls.batches.push(body.batch);
      return new Response("{}", { status: 200 });
    }
    throw new Error(`unexpected fetch ${u}`);
  };
  return { fn, calls };
}

test("a short run sends only recent sign-ups and sign-ins that have an email", async () => {
  const { fn, calls } = fakeFetch(USERS);
  const r = await syncEmails(env, sa, { now: NOW, fetch: fn });
  assert.deepEqual(r, { full: false, seen: 6, sent: 3 });
  assert.equal(calls.pages, 3);
  const sent = calls.batches.flat();
  assert.deepEqual(sent.map((e) => [e.distinct_id, e.properties.$set.email]), [
    ["new1", "new@example.com"],
    ["back1", "back@example.com"],
    ["relay", "x@privaterelay.appleid.com"],
  ]);
  for (const e of sent) assert.equal(e.event, "$set");
});

test("the Sunday run sends everyone with an email", async () => {
  const { fn, calls } = fakeFetch(USERS);
  const r = await syncEmails(env, sa, { full: true, now: NOW, fetch: fn });
  assert.equal(r.sent, 4);
  assert.deepEqual(calls.batches.flat().map((e) => e.distinct_id), ["new1", "back1", "old1", "relay"]);
});

test("nothing is sent when no one is recent", async () => {
  const { fn, calls } = fakeFetch([USERS[2]]);
  const r = await syncEmails(env, sa, { now: NOW, fetch: fn });
  assert.equal(r.sent, 0);
  assert.equal(calls.batches.length, 0);
});

test("helpers", () => {
  assert.equal(emailOf({ email: " A@B.co " }), "a@b.co");
  assert.equal(emailOf({ providerUserInfo: [{ email: "" }, { email: "p@q.co" }] }), "p@q.co");
  assert.equal(emailOf({}), null);
  assert.equal(isRecent({ createdAt: ago(10) }, NOW - 45 * 60_000), true);
  assert.equal(isRecent({ createdAt: ago(100), lastLoginAt: ago(50) }, NOW - 45 * 60_000), false);
  assert.equal(FULL_SYNC_CRON, "17 3 * * 0");
});
