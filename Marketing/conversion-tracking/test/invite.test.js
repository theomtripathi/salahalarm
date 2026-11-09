import { test } from "node:test";
import assert from "node:assert/strict";
import { parseCode, parseChallengePath, challengeTarget, oneLinkUrl } from "../src/invite.js";

const url = (path) => new URL(`https://salahalarm.com${path}`);
const ONELINK = "https://salahalarm.onelink.me/AbCd/challenge";

test("parses invite codes the way the app makes them", () => {
  assert.equal(parseCode("K7QX2M"), "K7QX2M");
  assert.equal(parseCode("k7qx2m/"), "K7QX2M");
  assert.equal(parseCode("K7QX2"), null);     // too short
  assert.equal(parseCode("K7QX0M"), null);    // 0 is not in the alphabet
  assert.equal(parseCode("KIQX2M"), null);    // nor I
  assert.deepEqual(parseChallengePath("/c/k7qx2m"), { kind: "invite", code: "K7QX2M" });
  assert.deepEqual(parseChallengePath("/c/join"), { kind: "join" });
  assert.deepEqual(parseChallengePath("/c/"), { kind: "join" });
  assert.deepEqual(parseChallengePath("/c/invite/"), { kind: "invite_link" });
  assert.equal(parseChallengePath("/c/hello-there").kind, "unknown");
});

test("with a OneLink, phones get the deep link with the code", () => {
  const r = challengeTarget(url("/c/K7QX2M?src=tt03"), { kind: "invite", code: "K7QX2M" }, "ios", { ONELINK_URL: ONELINK });
  assert.equal(r.destination, "onelink");
  const t = new URL(r.target);
  assert.equal(t.origin + t.pathname, ONELINK);
  assert.equal(t.searchParams.get("deep_link_value"), "challenge");
  assert.equal(t.searchParams.get("deep_link_sub1"), "K7QX2M");
  assert.equal(t.searchParams.get("pid"), "challenge_invite");
  assert.equal(t.searchParams.get("af_channel"), "tt03");
  assert.equal(t.searchParams.get("af_web_dp"), "https://salahalarm.com/ramadan-2027/?code=K7QX2M&src=tt03");

  const inv = new URL(oneLinkUrl(ONELINK, { kind: "invite_link" }));
  assert.equal(inv.searchParams.get("deep_link_value"), "challenge_invite");
  assert.equal(inv.searchParams.get("deep_link_sub1"), null);
});

test("without a OneLink, an invite shows the page with the code", () => {
  for (const os of ["ios", "other"]) {
    const r = challengeTarget(url("/c/K7QX2M"), { kind: "invite", code: "K7QX2M" }, os, {});
    assert.equal(r.target, "https://salahalarm.com/ramadan-2027/?code=K7QX2M");
  }
  // Desktop never goes to a phone store, even with a OneLink.
  const desk = challengeTarget(url("/c/K7QX2M"), { kind: "invite", code: "K7QX2M" }, "other", { ONELINK_URL: ONELINK });
  assert.equal(desk.destination, "page");
});

test("Android always goes to the web funnel with the invite code", () => {
  const r = challengeTarget(url("/c/k7qx2m?utm_source=tiktok&src=bio"), { kind: "invite", code: "K7QX2M" }, "android", { ONELINK_URL: ONELINK });
  assert.equal(r.destination, "android");
  assert.equal(r.target, "https://salahalarm.com/android/?invite=K7QX2M&ref=challenge&utm_source=tiktok");
});

test("join goes to the right store without a OneLink", () => {
  const ios = challengeTarget(url("/c/join?src=page"), { kind: "join" }, "ios", {});
  assert.equal(ios.target, "https://apps.apple.com/app/apple-store/id6758457826?pt=128487036&ct=ramadan-2027&mt=8");
  const android = challengeTarget(url("/c/join?src=page"), { kind: "join" }, "android", {});
  assert.equal(android.target, "https://salahalarm.com/android/?ref=challenge");
  const unknown = challengeTarget(url("/c/nope"), { kind: "unknown", raw: "nope" }, "ios", { ONELINK_URL: ONELINK });
  assert.equal(unknown.target, "https://salahalarm.com/ramadan-2027/");
});

test("worker logs the click to PostHog and redirects", async (t) => {
  // The worker imports links.json without an import attribute (wrangler bundles it),
  // so plain Node can only load it when bundled first.
  const { default: worker } = await import("../src/worker.js").catch(() => ({ default: null }));
  if (!worker) return t.skip("needs the wrangler/esbuild bundle");
  const sent = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (u, init) => { sent.push(JSON.parse(init.body)); return new Response("ok"); };
  try {
    const waits = [];
    const res = await worker.fetch(
      new Request("https://salahalarm.com/c/k7qx2m?src=bio", { headers: { "user-agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Instagram" } }),
      { POSTHOG_KEY: "phc_test" },
      { waitUntil: (p) => waits.push(p) },
    );
    await Promise.all(waits);
    assert.equal(res.status, 302);
    assert.equal(res.headers.get("location"), "https://salahalarm.com/ramadan-2027/?code=K7QX2M&src=bio");
    assert.equal(sent[0].event, "challenge_invite_clicked");
    assert.equal(sent[0].properties.invite_code, "K7QX2M");
    assert.equal(sent[0].properties.in_app_browser, "instagram");
  } finally {
    globalThis.fetch = realFetch;
  }
});

test("?to= picks the platform whatever the device", () => {
  const a = challengeTarget(url("/c/join?to=android&src=page"), { kind: "join" }, "other", {});
  assert.equal(a.target, "https://salahalarm.com/android/?ref=challenge");
  const i = challengeTarget(url("/c/join?to=ios&src=page"), { kind: "join" }, "android", {});
  assert.equal(i.destination, "app_store");
  const inv = challengeTarget(url("/c/K7QX2M?to=android"), { kind: "invite", code: "K7QX2M" }, "ios", {});
  assert.equal(inv.target, "https://salahalarm.com/android/?invite=K7QX2M&ref=challenge");
  // The page's own iPhone button must not loop back to the page.
  const iosInv = challengeTarget(url("/c/K7QX2M?to=ios&src=page-invite"), { kind: "invite", code: "K7QX2M" }, "ios", {});
  assert.equal(iosInv.destination, "app_store");
});
