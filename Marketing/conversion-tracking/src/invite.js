// Ramadan Ready challenge links on salahalarm.com/c/*.
//
//   /c/<CODE>   a joiner's personal invite link (CODE is made in the app)
//   /c/join     "Download and join" on the challenge page and in bios
//   /c/invite   "Get my invite link": opens the app on its invite screen
//
// Android goes to the web funnel at /android/ (with invite=CODE). With
// ONELINK_URL set, iPhones go to the AppsFlyer OneLink with
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

// Where a /c/ click goes. `os` is from classifyAgent; `?to=ios|android` (the
// page's iPhone and Android buttons) overrides it, so a desktop visitor who taps
// Android still reaches the Android funnel.
export function challengeTarget(url, link, agentOs, env = {}) {
  const to = url.searchParams.get("to");
  const os = to === "ios" || to === "android" ? to : agentOs;
  const src = (url.searchParams.get("src") || "").replace(/[^a-z0-9_-]/gi, "").slice(0, 32) || null;
  const code = link.kind === "invite" ? link.code : null;
  const page = challengePageUrl(url, code, src);
  if (link.kind === "unknown") return { target: challengePageUrl(url, null, src), destination: "page", src };

  // Android is not on Google Play: every Android click goes to the web funnel,
  // which stores the code, signs the person in and joins them on the server.
  if (os === "android") return { target: androidUrl(url, code), destination: "android", src };
  if (env.ONELINK_URL && os === "ios") {
    return { target: oneLinkUrl(env.ONELINK_URL, { kind: link.kind, code, src, pageUrl: page }), destination: "onelink", src };
  }
  // No OneLink yet, or a desktop: an invite shows the page with the code on it,
  // unless it came from that page's own iPhone button (?to=ios).
  if (link.kind === "invite" && !to) return { target: page, destination: "page", src };
  return { target: appStoreChallengeUrl(), destination: "app_store", src };
}

// Android web funnel: /android/?invite=CODE&ref=challenge, keeping utm_* params.
export function androidUrl(url, code) {
  const target = new URL("/android/", url);
  if (code) target.searchParams.set("invite", code);
  target.searchParams.set("ref", "challenge");
  for (const [k, v] of url.searchParams) if (k.startsWith("utm_")) target.searchParams.set(k, v);
  return target.href;
}
