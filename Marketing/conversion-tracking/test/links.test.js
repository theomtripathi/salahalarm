import { test } from "node:test";
import assert from "node:assert/strict";
import { buildLinks, campaignToken, classifyAgent, parseCsv } from "../src/links.js";

const config = {
  appStoreId: "6758457826", providerToken: "123456", domain: "salahalarm.com",
  formats: { whatif: "", anim: "" },
  accounts: [{ id: "tt03", platform: "tiktok", testFormat: "anim" }],
};

test("campaign tokens follow account-format-tail", () => {
  assert.equal(campaignToken({ account: "tt03", format: "anim" }), "tt03-anim-bio");
  assert.equal(campaignToken({ account: "tt03", format: "whatif", videoId: "tt03-1024-2" }), "tt03-whatif-1024-2");
  assert.throws(() => campaignToken({ account: "tt03", format: "x".repeat(40) }), /too long/);
  assert.equal(campaignToken({ account: "seo-en", format: "seo" }), "seo-en-bio");
  assert.equal(campaignToken({ account: "seo-en", format: "seo", videoId: "seo-en-fajr-tips" }), "seo-en-fajr-tips");
});

test("builds bio and video links pointing at App Store campaign URLs", () => {
  const links = buildLinks(config, [{ video_id: "tt03-1024-1", account: "tt03", format: "whatif", hook: "fajr" }]);
  assert.equal(links.tt03.ct, "tt03-anim-bio");
  assert.equal(links["v/tt03-1024-1"].ct, "tt03-whatif-1024-1");
  assert.equal(links["v/tt03-1024-1"].target,
    "https://apps.apple.com/app/apple-store/id6758457826?pt=123456&ct=tt03-whatif-1024-1&mt=8");
});

test("rejects bad video rows", () => {
  assert.throws(() => buildLinks(config, [{ video_id: "tt09-1024-1", account: "tt09", format: "whatif" }]), /unknown account/);
  assert.throws(() => buildLinks(config, [{ video_id: "tt03-1024-1", account: "tt03", format: "nope" }]), /unknown format/);
  assert.throws(() => buildLinks(config, [{ video_id: "x-1", account: "tt03", format: "anim" }]), /must start with/);
  const v = { video_id: "tt03-1024-1", account: "tt03", format: "anim" };
  assert.throws(() => buildLinks(config, [v, v]), /duplicate/);
});

test("classifies in-app browsers and bots", () => {
  assert.deepEqual(classifyAgent("Mozilla/5.0 (iPhone) Instagram 300.0"), { os: "ios", in_app_browser: "instagram", is_bot: false });
  assert.equal(classifyAgent("Mozilla/5.0 (iPhone) musical_ly_32.1").in_app_browser, "tiktok");
  assert.equal(classifyAgent("facebookexternalhit/1.1").is_bot, true);
});

test("parses the videos csv", () => {
  assert.deepEqual(parseCsv("a,b\n1,2\n"), [{ a: "1", b: "2" }]);
});
