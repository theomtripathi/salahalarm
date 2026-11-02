// Ramadan Ready challenge links on salahalarm.com/c/*.
//
//   /c/<CODE>   a joiner's personal invite link (CODE is made in the app)
//   /c/join     "Download and join" on the challenge page and in bios
//   /c/invite   "Get my invite link": opens the app on its invite screen
//
// With ONELINK_URL set, phones go to the AppsFlyer OneLink with
// deep_link_value / deep_link_sub1, so the app gets the code on first open
// (deferred deep link) or straight away when it is already installed.
// Without it (or on a desktop for an invite), an invite opens the challenge page
// with the code shown, so the friend can type it into "Got an invite code?".

// Same alphabet as the app: uppercase, no 0/O/1/I/L.
export const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_RE = new RegExp(`^[${CODE_ALPHABET}]{6}$`);

export const CHALLENGE_PAGE = "/ramadan-2027/";
export const CHALLENGE_CT = "ramadan-2027";

// Accepts lower case and trailing slashes (people retype links). Returns the
// normalised code, or null when it cannot be a code.
export function parseCode(raw) {
  const code = String(raw || "").trim().replace(/\/+$/, "").toUpperCase();
  return CODE_RE.test(code) ? code : null;
}

// What kind of /c/ link this is: { kind: "invite", code } | { kind: "join" } |
// { kind: "invite_link" } | { kind: "unknown", raw }.
export function parseChallengePath(pathname) {
  const rest = pathname.replace(/^\/c\/?/, "").replace(/\/+$/, "");
  if (rest.toLowerCase() === "join" || rest === "") return { kind: "join" };
  if (rest.toLowerCase() === "invite") return { kind: "invite_link" };
  const code = parseCode(rest);
  return code ? { kind: "invite", code } : { kind: "unknown", raw: rest.slice(0, 40) };
}

export function appStoreChallengeUrl(appStoreId = "6758457826", providerToken = "128487036", ct = CHALLENGE_CT) {
  const params = new URLSearchParams({ pt: providerToken, ct, mt: "8" });
  return `https://apps.apple.com/app/apple-store/id${appStoreId}?${params}`;
}

export function challengePageUrl(url, code, src) {
  const target = new URL(CHALLENGE_PAGE, url);
  if (code) target.searchParams.set("code", code);
  if (src) target.searchParams.set("src", src);
  return target.href;
}

// The OneLink with the challenge deep link. `src` (bio, page, story…) becomes
// the AppsFlyer channel so installs split by where the link was tapped.
export function oneLinkUrl(base, { kind, code, src, pageUrl }) {
  const target = new URL(base);
  const p = target.searchParams;
  p.set("pid", kind === "invite" ? "challenge_invite" : "challenge");
  p.set("c", CHALLENGE_CT);
  if (src) p.set("af_channel", src);
  p.set("deep_link_value", kind === "invite_link" ? "challenge_invite" : "challenge");
  if (code) {
    p.set("deep_link_sub1", code);
    p.set("af_sub1", code);
  }
  // Desktop clicks land on the challenge page instead of a store.
  if (pageUrl) p.set("af_web_dp", pageUrl);
  return target.href;
}

// Where a /c/ click goes. `os` is from classifyAgent.
export function challengeTarget(url, link, os, env = {}) {
  const src = (url.searchParams.get("src") || "").replace(/[^a-z0-9_-]/gi, "").slice(0, 32) || null;
  const code = link.kind === "invite" ? link.code : null;
  const page = challengePageUrl(url, code, src);
  if (link.kind === "unknown") return { target: challengePageUrl(url, null, src), destination: "page", src };

  const phone = os === "ios" || os === "android";
  if (env.ONELINK_URL && phone) {
    return { target: oneLinkUrl(env.ONELINK_URL, { kind: link.kind, code, src, pageUrl: page }), destination: "onelink", src };
  }
  // No OneLink yet, or a desktop: an invite always shows the page with the code on it.
  if (link.kind === "invite") return { target: page, destination: "page", src };
  if (os === "android") {
    const android = new URL("/android/", url);
    android.searchParams.set("a", CHALLENGE_CT);
    if (src) android.searchParams.set("from", src);
    return { target: android.href, destination: "android", src };
  }
  return { target: appStoreChallengeUrl(), destination: "app_store", src };
}
