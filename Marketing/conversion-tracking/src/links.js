// Pure link logic shared by the redirect worker and the generator.

export const CT_MAX = 40; // App Store Connect campaign token limit

export function slugify(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

// Campaign token Apple stores and reports in App Analytics > Campaigns.
// Account links:  tt03-anim-bio      Video links: tt03-anim-1024-1
// Accounts already named after their format skip the repeat: seo-en-bio, seo-en-fajr-tips
export function campaignToken({ account, format, videoId }) {
  const tail = videoId ? videoId.slice(account.length + 1) : "bio";
  const prefix = account.startsWith(`${format}-`) ? account : `${account}-${format}`;
  const ct = slugify(`${prefix}-${tail}`);
  if (ct.length > CT_MAX) throw new Error(`campaign token too long (${ct.length}): ${ct}`);
  return ct;
}

export function appStoreUrl({ appStoreId, providerToken, ct }) {
  const params = new URLSearchParams({ pt: providerToken, ct, mt: "8" });
  return `https://apps.apple.com/app/apple-store/id${appStoreId}?${params}`;
}

export function buildLinks(config, videos) {
  const accounts = new Map(config.accounts.map((a) => [a.id, a]));
  const links = {};
  const add = (slug, meta) => {
    if (links[slug]) throw new Error(`duplicate slug: ${slug}`);
    links[slug] = { ...meta, target: appStoreUrl({ ...config, ct: meta.ct }) };
  };
  for (const a of config.accounts) {
    add(a.id, { kind: "bio", account: a.id, platform: a.platform, format: a.testFormat, video: null,
      ct: campaignToken({ account: a.id, format: a.testFormat }) });
  }
  for (const v of videos) {
    const a = accounts.get(v.account);
    if (!a) throw new Error(`video ${v.video_id}: unknown account ${v.account}`);
    if (!(v.format in config.formats)) throw new Error(`video ${v.video_id}: unknown format ${v.format}`);
    if (!v.video_id.startsWith(`${a.id}-`)) throw new Error(`video ${v.video_id}: id must start with ${a.id}-`);
    add(`v/${v.video_id}`, { kind: "video", account: a.id, platform: a.platform, format: v.format,
      video: v.video_id, hook: v.hook || null, ct: campaignToken({ account: a.id, format: v.format, videoId: v.video_id }) });
  }
  return links;
}

export function parseCsv(text) {
  const [header, ...rows] = text.trim().split(/\r?\n/).filter(Boolean);
  const cols = header.split(",");
  return rows.map((r) => Object.fromEntries(r.split(",").map((v, i) => [cols[i], v.trim()])));
}

const BOT = /bot|crawl|spider|preview|facebookexternalhit|bytespider|whatsapp|telegram|slack|discord/i;

export function classifyAgent(ua = "") {
  return {
    os: /iphone|ipad|ipod/i.test(ua) ? "ios" : /android/i.test(ua) ? "android" : "other",
    in_app_browser: /instagram/i.test(ua) ? "instagram" : /musical_ly|tiktok|bytedance/i.test(ua) ? "tiktok" : null,
    is_bot: BOT.test(ua),
  };
}

// The iOS/Android chooser for a short link; `a` carries the slug for attribution.
export function chooserUrl(url, slug) {
  const target = new URL("/get/", url);
  if (slug) target.searchParams.set("a", slug);
  return target.href;
}

// Email campaign links: one URL for every device. When the iOS app is installed,
// a universal link opens it before this runs; otherwise iPhones go to the App Store
// and everyone else to the Android web paywall with the discount already applied.
export const CAMPAIGNS = {
  comeback: { discount: "COMEBACK33", ct: "email-comeback" },
};

export function campaignUrl(url, slug, os, appStoreId = "6758457826") {
  const c = CAMPAIGNS[slug];
  if (!c) return null;
  if (os === "ios") return `https://apps.apple.com/app/apple-store/id${appStoreId}?ct=${c.ct}&mt=8`;
  const target = new URL("/android/", url);
  for (const [k, v] of url.searchParams) target.searchParams.set(k, v);
  if (!target.searchParams.has("ref")) target.searchParams.set("ref", "email");
  target.searchParams.set("discount", c.discount);
  target.searchParams.set("resume", "paywall");
  return target.href;
}
