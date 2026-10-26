// Shared helpers for the bio link, onboarding and install pages.

export const LANGS = [
  { code: "en", name: "English" },
  { code: "ar", name: "العربية" },
  { code: "tr", name: "Türkçe" },
  { code: "id", name: "Bahasa Indonesia" },
  { code: "ur", name: "اردو" },
];
const RTL = new Set(["ar", "ur"]);
const store = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch { /* private mode */ } },
  del(k) { try { localStorage.removeItem(k); } catch { /* private mode */ } },
};
export { store };

// ---- language ---------------------------------------------------------------

let lang = "en";
export function currentLang() { return lang; }

export function initialLang(fallback) {
  const fromUrl = new URLSearchParams(location.search).get("lang");
  const saved = store.get("sa_lang");
  const nav = (navigator.language || "en").split("-")[0].toLowerCase();
  for (const candidate of [fromUrl, saved, fallback, nav === "in" ? "id" : nav]) {
    if (LANGS.some((l) => l.code === candidate)) return candidate;
  }
  return "en";
}

export function setLang(code, { persist = true } = {}) {
  lang = LANGS.some((l) => l.code === code) ? code : "en";
  if (persist) store.set("sa_lang", lang);
  document.documentElement.lang = lang;
  document.documentElement.dir = RTL.has(lang) ? "rtl" : "ltr";
  loadFonts(lang);
  translateStatic();
}

const loadedFonts = new Set();
function loadFonts(code) {
  const family = code === "ar" ? "Noto+Naskh+Arabic:wght@400;600;700" : code === "ur" ? "Noto+Nastaliq+Urdu:wght@400;600;700" : null;
  if (!family || loadedFonts.has(family)) return;
  loadedFonts.add(family);
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = `https://fonts.googleapis.com/css2?family=${family}&display=swap`;
  document.head.append(link);
}

/** Translates an English source string (iOS catalog key) and fills %@ / %d / %1$@ placeholders. */
export function t(key, ...args) {
  const table = (window.SA_I18N && window.SA_I18N[lang]) || {};
  const template = table[key] ?? key;
  let i = 0;
  return template.replace(/%(?:(\d+)\$)?[@d]/g, (_, pos) => {
    const value = pos ? args[Number(pos) - 1] : args[i++];
    return value == null ? "" : String(value);
  });
}

export function translateStatic(root = document) {
  for (const el of root.querySelectorAll("[data-t]")) el.textContent = t(el.dataset.t);
  for (const el of root.querySelectorAll("[data-t-aria]")) el.setAttribute("aria-label", t(el.dataset.tAria));
}

export function langSelect(onChange) {
  const select = document.createElement("select");
  select.className = "lang-select";
  select.setAttribute("aria-label", "Language");
  for (const l of LANGS) select.append(new Option(l.name, l.code, false, l.code === lang));
  select.addEventListener("change", () => {
    setLang(select.value);
    capture("web_language_changed", { language: select.value });
    onChange?.(select.value);
  });
  return select;
}

// ---- device -------------------------------------------------------------------

const ua = navigator.userAgent || "";
export const device = {
  android: /android/i.test(ua),
  ios: /iphone|ipad|ipod/i.test(ua) || (/macintosh/i.test(ua) && navigator.maxTouchPoints > 1),
  inApp: /instagram/i.test(ua) ? "instagram"
    : /musical_ly|tiktok|bytedance|trill/i.test(ua) ? "tiktok"
    : /fban|fbav|fb_iab|fbios/i.test(ua) ? "facebook"
    : /snapchat/i.test(ua) ? "snapchat"
    : /twitter/i.test(ua) ? "twitter"
    : /; wv\)/.test(ua) ? "webview"
    : null,
};

/**
 * Link that reopens `url` in Chrome from an Android in-app browser (TikTok, Instagram...).
 * Google sign-in and APK downloads both fail inside those browsers.
 */
export function chromeIntent(url) {
  const u = new URL(url, location.href);
  return `intent://${u.host}${u.pathname}${u.search}${u.hash}#Intent;scheme=https;package=com.android.chrome;S.browser_fallback_url=${encodeURIComponent(u.href)};end`;
}

// ---- attribution --------------------------------------------------------------

export function captureRef() {
  const params = new URLSearchParams(location.search);
  const ref = params.get("ref") || params.get("a") || params.get("utm_campaign");
  if (ref) store.set("sa_ref", ref.slice(0, 60));
  // Which button sent them (e.g. the homepage section), for per-CTA conversion.
  const from = params.get("from");
  if (from) store.set("sa_from", from.slice(0, 60));
  return store.get("sa_ref") || "";
}

// ---- analytics (PostHog capture API, no SDK) --------------------------------------

let posthog = null;
let distinctId = store.get("sa_did");
if (!distinctId) {
  distinctId = (crypto.randomUUID && crypto.randomUUID()) || String(Math.random()).slice(2);
  store.set("sa_did", distinctId);
}
const superProps = {};

export function initAnalytics(config, props = {}) {
  posthog = config?.posthog || null;
  Object.assign(superProps, store.get("sa_from") ? { from: store.get("sa_from") } : {}, props);
}

export function capture(event, properties = {}) {
  if (!posthog) return;
  const body = JSON.stringify({
    api_key: posthog.key,
    event,
    distinct_id: distinctId,
    properties: {
      ...superProps,
      ...properties,
      app_language: lang,
      os: device.android ? "android" : device.ios ? "ios" : "other",
      in_app_browser: device.inApp,
      $current_url: location.href,
      $referrer: document.referrer || null,
    },
    timestamp: new Date().toISOString(),
  });
  const url = `${posthog.host}/capture/`;
  if (navigator.sendBeacon && navigator.sendBeacon(url, new Blob([body], { type: "text/plain" }))) return;
  fetch(url, { method: "POST", body, keepalive: true, headers: { "content-type": "text/plain" } }).catch(() => {});
}

/** Links this browser's anonymous events to the Firebase uid (same id the app uses). */
export function identify(uid, email) {
  if (!posthog || !uid || store.get("sa_identified") === uid) return;
  capture("$identify", { $anon_distinct_id: distinctId, $set: { email } });
  distinctId = uid;
  store.set("sa_did", uid);
  store.set("sa_identified", uid);
}

// ---- API ---------------------------------------------------------------------------

export async function api(path, { method = "GET", token, body } = {}) {
  const res = await fetch(path, {
    method,
    headers: {
      ...(token && { authorization: `Bearer ${token}` }),
      ...(body && { "content-type": "application/json" }),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = await res.json(); } catch { data = null; }
  if (!res.ok) {
    const err = new Error(data?.error || `Request failed (${res.status})`);
    err.status = res.status;
    throw err;
  }
  return data;
}

let configPromise = null;
export function loadConfig() {
  configPromise ||= api("/api/config").catch(() => ({ plans: [], geo: {}, lang: "en" }));
  return configPromise;
}

// ---- small DOM helpers ------------------------------------------------------------

export function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k === "class") el.className = v;
    else if (k === "html") el.innerHTML = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, v === true ? "" : v);
  }
  for (const c of children.flat(Infinity)) {
    if (c == null || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

export function money(amount, currency) {
  try {
    return new Intl.NumberFormat(lang === "ar" ? "ar-u-nu-latn" : lang, {
      style: "currency",
      currency,
      maximumFractionDigits: amount >= 1000 ? 0 : 2,
      minimumFractionDigits: amount >= 1000 || Number.isInteger(amount) ? 0 : 2,
    }).format(amount);
  } catch {
    return `${currency} ${amount}`;
  }
}

export function timeIn(iso, timeZone) {
  try {
    return new Intl.DateTimeFormat(lang === "ar" ? "ar-u-nu-latn" : lang, { hour: "numeric", minute: "2-digit", timeZone: timeZone || undefined }).format(new Date(iso));
  } catch {
    return new Date(iso).toLocaleTimeString();
  }
}

export const icons = {
  back: '<svg class="flip" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 18l-6-6 6-6"/></svg>',
  bell: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6V11a7 7 0 0 0-5.5-6.84V3.5a1.5 1.5 0 0 0-3 0v.66A7 7 0 0 0 5 11v5l-2 2v1h18v-1l-2-2Z"/></svg>',
  walk: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><circle cx="13.5" cy="4" r="2"/><path d="M10.2 8.6 7.5 20h2.1l1.8-7.4 2.1 2V20h2v-6.2l-2.1-2 .6-3A6 6 0 0 0 18 12v-2a4 4 0 0 1-3.4-1.9l-1-1.6A2 2 0 0 0 11.9 5.6L7 7.6V12h2V8.9l1.2-.3Z"/></svg>',
  scan: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/><rect x="8" y="8" width="8" height="8" rx="1.5"/></svg>',
  apps: '<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="3" width="8" height="8" rx="2"/><rect x="3" y="13" width="8" height="8" rx="2"/><rect x="13" y="13" width="8" height="8" rx="2" opacity=".45"/></svg>',
  check: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  seal: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 1.5l2.6 1.9 3.2-.1 1 3 2.6 1.9-1 3 1 3-2.6 1.9-1 3-3.2-.1L12 22.5l-2.6-1.9-3.2.1-1-3-2.6-1.9 1-3-1-3 2.6-1.9 1-3 3.2.1Z"/><path d="M8 12.3l2.7 2.7L16.3 9.4" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  alarm: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 4a9 9 0 1 0 0 18 9 9 0 0 0 0-18Zm1 9.4V8h-2v6.2l4.3 2.6 1-1.7ZM4.8 1.6 1.6 4.3l1.3 1.5 3.2-2.7ZM19.2 1.6l-1.3 1.5 3.2 2.7 1.3-1.5Z"/></svg>',
  shield: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2 4 5v6c0 5 3.4 9.7 8 11 4.6-1.3 8-6 8-11V5Zm0 2.2V19.8C8.6 18.6 6 15 6 11V6.4Z"/></svg>',
  target: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/></svg>',
  lock: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M17 9V7A5 5 0 0 0 7 7v2H5v13h14V9Zm-8-2a3 3 0 0 1 6 0v2H9Z"/></svg>',
  flame: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2c1 3.5-2 5-2 8a2 2 0 0 0 4 0c0-1-.5-2-.5-2C16 10 18 12.5 18 15a6 6 0 0 1-12 0c0-4.5 4.5-7 6-13Z"/></svg>',
  google: '<svg width="20" height="20" viewBox="0 0 48 48" aria-hidden="true"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36a12 12 0 1 1 7.9-21l5.7-5.7A20 20 0 1 0 44 24c0-1.2-.1-2.3-.4-3.5Z"/><path fill="#FF3D00" d="m6.3 14.7 6.6 4.8A12 12 0 0 1 31.9 15l5.7-5.7A20 20 0 0 0 6.3 14.7Z"/><path fill="#4CAF50" d="M24 44a20 20 0 0 0 13.5-5.2l-6.2-5.3A12 12 0 0 1 12.7 28l-6.5 5A20 20 0 0 0 24 44Z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3a12 12 0 0 1-4 5.5l6.2 5.3C37 39.2 44 34 44 24c0-1.2-.1-2.3-.4-3.5Z"/></svg>',
  android: '<svg width="26" height="26" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M17.6 9.48l1.84-3.18a.38.38 0 0 0-.66-.38l-1.86 3.22a11.4 11.4 0 0 0-9.84 0L5.22 5.92a.38.38 0 0 0-.66.38L6.4 9.48A10.8 10.8 0 0 0 1 18h22a10.8 10.8 0 0 0-5.4-8.52ZM7 15.25A1.25 1.25 0 1 1 8.25 14 1.25 1.25 0 0 1 7 15.25Zm10 0A1.25 1.25 0 1 1 18.25 14 1.25 1.25 0 0 1 17 15.25Z"/></svg>',
  apple: '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.37 12.6c-.02-2.3 1.88-3.4 1.96-3.46a4.24 4.24 0 0 0-3.32-1.8c-1.4-.14-2.75.83-3.47.83-.72 0-1.82-.81-3-.79a4.44 4.44 0 0 0-3.75 2.28c-1.6 2.78-.41 6.9 1.15 9.16.76 1.1 1.67 2.34 2.86 2.3 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.77.74 2.98.72 1.24-.02 2.02-1.12 2.77-2.23a9.8 9.8 0 0 0 1.26-2.58 3.98 3.98 0 0 1-2.38-3.69ZM14.1 5.86A4.02 4.02 0 0 0 15.03 3a4.1 4.1 0 0 0-2.66 1.37 3.83 3.83 0 0 0-.95 2.78 3.39 3.39 0 0 0 2.68-1.29Z"/></svg>',
  download: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12M7 10l5 5 5-5M4 20h16"/></svg>',
  card: '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2 4 5v6c0 5 3.4 9.7 8 11 4.6-1.3 8-6 8-11V5Z"/></svg>',
};
