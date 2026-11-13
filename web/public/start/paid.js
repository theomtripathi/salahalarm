// After payment on salahalarm.com (/start/paid/), before the download:
//   1. seat     "You've paid, so you get one seat for the Ramadan challenge."
//   2. platform "Do you use Android or iOS?"
//   3. install  the right store, with sign-in steps (same account on the phone)
//   4. more     "Want more seats?" share link, seat rules and progress
// Every step is a PostHog funnel step (session replay on), mirrored to Firebase Analytics.

import {
  t, h, setLang, initialLang, langSelect, loadConfig, initAnalytics, capture, identify, captureRef,
  device, api, icons, store, affiliate, affiliateBeacon, setPersonProps,
} from "/assets/common.js";
import { initAuth, authErrorMessage } from "/assets/auth.js";

const STEPS = ["seat", "platform", "install", "more"];
const root = document.getElementById("ob");
const app = root.querySelector("[data-ob-app]");

let config = {};
let auth = null;
let user = null;
let screenName = "checking";
let platform = store.get("sa_platform") || (device.ios ? "ios" : device.android ? "android" : null);
let seats = null; // { code, shareUrl, seats, total, paid }
let shownAt = Date.now();
let aff = "";

function svg(markup) {
  const span = document.createElement("span");
  span.innerHTML = markup;
  return span.firstElementChild;
}

function go(name) {
  if (STEPS.includes(screenName)) capture("web_postpay_step_completed", { step: screenName, duration_ms: Date.now() - shownAt });
  screenName = name;
  render();
}

function render() {
  root.dataset.screen = screenName;
  root.dataset.theme = screenName === "seat" || screenName === "checking" || screenName === "pending" ? "night" : "day";
  app.replaceChildren(SCREENS[screenName]());
  window.scrollTo(0, 0);
  shownAt = Date.now();
  const i = STEPS.indexOf(screenName);
  capture("web_onboarding_screen_viewed", { screen: `paid_${screenName}`, index: i + 1, total: STEPS.length, flow: "postpay" });
}

function screen(body, footer) {
  return h("section", { class: "ob-screen" }, h("div", { class: "ob-body" }, body), footer ? h("div", { class: "ob-foot" }, footer) : null);
}
const primary = (label, onclick, attrs = {}) => h("button", { class: "ob-btn ob-btn-primary", type: "button", onclick, ...attrs }, t(label));
const title = (text) => h("h1", { class: "ob-h1" }, t(text));
const lede = (text) => h("p", { class: "ob-lede" }, t(text));

function confetti() {
  const box = h("div", { class: "ob-confetti", "aria-hidden": "true" });
  const colors = ["#c9a028", "#f3e2a9", "#1a9e3f", "#ffffff", "#e5483d"];
  for (let i = 0; i < 70; i++) {
    box.append(h("i", { style: `left:${Math.random() * 100}%;background:${colors[i % colors.length]};animation-duration:${2 + Math.random() * 2.5}s;animation-delay:${Math.random() * 0.6}s` }));
  }
  document.body.append(box);
  setTimeout(() => box.remove(), 5500);
}

const APP_STORE = () => config.appStoreUrl || "https://apps.apple.com/app/id6758457826";

const SCREENS = {
  checking() {
    return screen([h("div", { class: "ob-loader" },
      h("div", { class: "ob-spinner", style: "width:38px;height:38px;margin:0 auto" }),
      title("Confirming your payment…"),
      lede("This usually takes a few seconds."))]);
  },

  pending() {
    return screen([
      title("Your payment is still processing"),
      lede("Some banks take a minute. Keep this page open, or come back to salahalarm.com/start/paid/ shortly. You won't be charged twice."),
    ], [primary("Check again", () => confirm())]);
  },

  signin() {
    const error = h("p", { class: "ob-error", hidden: true, role: "alert" });
    const show = (m) => { error.hidden = !m; error.textContent = m || ""; };
    const email = h("input", { id: "pp-email", type: "email", autocomplete: "email", inputmode: "email" });
    const password = h("input", { id: "pp-password", type: "password", autocomplete: "current-password" });
    const google = h("button", { class: "ob-btn ob-google", type: "button" }, svg(icons.google), t("Continue with Google"));
    google.addEventListener("click", async () => {
      show(null);
      try { const u = await auth.google(); if (u) await signedIn(u); } catch (err) { show(authErrorMessage(err, t)); }
    });
    const form = h("form", { novalidate: true },
      h("div", { class: "ob-field" }, h("label", { for: "pp-email" }, t("Email")), email),
      h("div", { class: "ob-field" }, h("label", { for: "pp-password" }, t("Password")), password),
      h("button", { class: "ob-btn ob-btn-primary", type: "submit" }, t("Sign in")));
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      show(null);
      try { await signedIn(await auth.email(email.value.trim(), password.value, "")); } catch (err) { show(authErrorMessage(err, t)); }
    });
    return screen([
      title("Sign in to get your app"),
      lede("Use the account you paid with."),
      google, h("div", { class: "ob-divider" }, t("or")), form, error,
      h("p", { class: "ob-small", style: "margin-top:14px" }, t("Haven't paid yet?"), " ", h("a", { href: "/start/" }, t("Build your plan"))),
    ]);
  },

  notpaid() {
    return screen([
      title("We couldn't find a plan on this account"),
      lede("If you paid with a different account, sign out and sign in with that one. Otherwise, start your plan here."),
    ], [
      h("a", { class: "ob-btn ob-btn-primary", href: "/start/?resume=paywall" }, t("See plans")),
      h("button", { class: "ob-link", type: "button", onclick: async () => { await auth.signOut(); user = null; go("signin"); } }, t("Use a different account")),
    ]);
  },

  // 1. The seat.
  seat() {
    setTimeout(confetti, 150);
    const n = seats?.total || 1;
    return screen([
      h("p", { class: "ob-chip", style: "margin-bottom:14px" }, "✓ ", t("Payment confirmed")),
      h("div", { class: "ob-ticket", style: "margin-bottom:20px" },
        h("div", { class: "kaaba", "aria-hidden": "true" }),
        h("div", { class: "k" }, t("Ramadan 2027 challenge")),
        h("div", { class: "big" }, t("Free Makkah Trip draw")),
        h("div", { class: "seat" }, "🎟️ ", n === 1 ? t("Seat #1 is yours") : t("%d seats", n))),
      title("You've paid, so you get one seat for the Ramadan challenge."),
      lede("Your seat is in the draw for Umrah for two: flights, visas and a hotel by the Haram. The draw is on 10 February 2027."),
      h("p", { class: "ob-small" }, t("A random draw: every seat is a chance, nobody is guaranteed to win."), " ", h("a", { href: "/ramadan-2027/rules/", target: "_blank", rel: "noopener" }, t("Rules"))),
    ], primary("Get the app", () => go("platform")));
  },

  // 2. Android or iOS?
  platform() {
    const pick = (p) => {
      platform = p;
      store.set("sa_platform", p);
      capture("web_store_chosen", { platform: p, detected: device.ios ? "ios" : device.android ? "android" : "other" });
      setPersonProps({ platform: p });
      user?.token().then((token) => api("/api/seats/platform", { method: "POST", token, body: { platform: p } })).catch(() => {});
      go("install");
    };
    const btn = (p, icon, label) => h("button", {
      class: `ob-btn ob-store ${platform === p ? "ob-btn-primary" : "ob-btn-ghost"}`, type: "button", onclick: () => pick(p),
    }, svg(icon), t(label));
    const order = platform === "android" ? [["android", icons.android, "Android"], ["ios", icons.apple, "iPhone (iOS)"]] : [["ios", icons.apple, "iPhone (iOS)"], ["android", icons.android, "Android"]];
    return screen([
      h("p", { class: "ob-kicker" }, t("Step 2 of 4")),
      title("Do you use Android or iOS?"),
      lede("We'll send you to the right place to download Salah Alarm."),
      h("div", { style: "display:grid;gap:12px" }, order.map(([p, ic, l]) => btn(p, ic, l))),
    ]);
  },

  // 3. Install, with the sign-in step that unlocks Premium.
  install() {
    const email = user?.email;
    const google = String(user?.provider || "").includes("google");
    const how = google ? t("Tap Continue with Google and pick %@", email || t("the same Google account")) : t("Sign in with email: %@ and the password you just created", email || t("your email"));
    const toStore = () => {
      capture("web_store_redirect", { platform });
      affiliateBeacon("store_redirect", { app_user_id: user?.uid, platform, plan: null });
      setTimeout(() => go("more"), 600);
    };
    if (platform === "ios") {
      return screen([
        h("p", { class: "ob-kicker" }, t("Step 3 of 4")),
        title("Get Salah Alarm on your iPhone"),
        h("ol", { class: "ob-steps", style: "margin:6px 0 18px" },
          h("li", {}, h("span", {}, t("Download Salah Alarm from the App Store."))),
          h("li", {}, h("span", {}, h("b", {}, t("Open the app and tap Sign in.")), " ", t("Don't buy again: your Premium is already paid."))),
          h("li", {}, h("span", {}, how)),
          h("li", {}, h("span", {}, t("Premium and your draw seat unlock on that account.")))),
        h("p", { class: "ob-notice" }, t("Use the same account you paid with. Signing in with Apple or a different email creates a new account without your plan.")),
      ], [
        h("a", { class: "ob-btn ob-btn-dark ob-store", href: APP_STORE(), target: "_blank", rel: "noopener", onclick: toStore }, svg(icons.apple), t("Download on the App Store")),
        h("button", { class: "ob-link", type: "button", onclick: () => go("platform") }, t("I use Android")),
      ]);
    }
    return screen([
      h("p", { class: "ob-kicker" }, t("Step 3 of 4")),
      title("Get Salah Alarm on your Android phone"),
      h("ol", { class: "ob-steps", style: "margin:6px 0 18px" },
        h("li", {}, h("span", {}, t("Tap Download for Android. The next page downloads the app and shows you how to install it."))),
        h("li", {}, h("span", {}, h("b", {}, t("Open the app and sign in.")), " ", t("Your Premium is already paid."))),
        h("li", {}, h("span", {}, how))),
      device.inApp ? h("p", { class: "ob-notice" }, t("Downloads don't work inside this app's browser. Tap ⋮ and choose Open in browser first.")) : null,
    ], [
      h("a", { class: "ob-btn ob-btn-primary ob-store", href: "/android/install/?from=start", onclick: toStore }, svg(icons.android), t("Download for Android")),
      h("button", { class: "ob-link", type: "button", onclick: () => go("more") }, t("I'll download it later")),
      h("button", { class: "ob-link", type: "button", onclick: () => go("platform") }, t("I use iPhone")),
    ]);
  },

  // 4. More seats.
  more() {
    const url = seats?.shareUrl;
    const s = seats?.seats || { paid: 1, shared: 0, friends: 0 };
    const total = h("b", {}, String(seats?.total ?? 1));
    const shareRow = h("div", { class: `s${s.shared ? " got" : ""}` }, h("span", {}, t("Share your link")), h("b", {}, s.shared ? "+1 ✓" : "+1"));
    const markShared = async (method) => {
      capture("web_share_link_shared", { code: seats?.code, method });
      if (s.shared) return;
      try {
        const r = await api("/api/seats/share", { method: "POST", token: await user.token(), body: { method } });
        if (r.granted) {
          s.shared = 1;
          seats.total = (seats.total || 1) + 1;
          total.textContent = String(seats.total);
          shareRow.className = "s got";
          shareRow.lastChild.textContent = "+1 ✓";
          setPersonProps({ challenge_seats: seats.total });
        }
      } catch { /* ignore */ }
    };
    const text = t("I'm getting ready for Ramadan with Salah Alarm. Join me in the Free Makkah Trip challenge:");
    const copyBtn = h("button", { class: "ob-btn ob-btn-ghost", type: "button", style: "min-height:44px;width:auto;padding:8px 14px;font-size:14px" }, t("Copy"));
    copyBtn.addEventListener("click", async () => {
      try { await navigator.clipboard.writeText(url); copyBtn.textContent = t("Copied"); } catch { /* ignore */ }
      capture("web_share_link_copied", { code: seats?.code });
      markShared("copy");
    });
    const share = h("button", { class: "ob-btn ob-btn-primary", type: "button" }, t("Share my link"));
    share.addEventListener("click", async () => {
      if (navigator.share) {
        try { await navigator.share({ title: "Salah Alarm", text, url }); markShared("native"); } catch { /* cancelled */ }
      } else {
        copyBtn.click();
      }
    });
    const wa = h("a", { class: "ob-btn ob-btn-ghost", href: `https://wa.me/?text=${encodeURIComponent(`${text} ${url}`)}`, target: "_blank", rel: "noopener", onclick: () => markShared("whatsapp") }, "💬 ", t("Send on WhatsApp"));
    return screen([
      h("p", { class: "ob-kicker" }, t("Step 4 of 4")),
      title("Want more seats in the challenge?"),
      lede("Every seat is another chance in the draw. Share your link, make a video about your Fajr journey, and bring your friends."),
      url ? h("div", { class: "ob-share", style: "margin-bottom:16px" }, h("div", { class: "ob-code" }, h("span", {}, url), copyBtn), share, wa)
        : h("p", { class: "ob-notice", style: "margin-bottom:16px" }, t("Your link appears here once your seat is confirmed. Refresh in a minute.")),
      h("div", { class: "ob-card ob-seats" },
        h("div", { class: "s got" }, h("span", {}, t("You paid")), h("b", {}, "1 ✓")),
        shareRow,
        h("div", { class: `s${s.friends ? " got" : ""}` }, h("span", {}, t("Each friend who joins with your link")), h("b", {}, s.friends ? t("+%d so far", s.friends) : "+1")),
        h("div", { class: "s" }, h("span", {}, t("Log all 5 prayers for 30 / 60 / 90 days")), h("b", {}, "+1 / +2 / +3")),
        h("div", { class: "s" }, h("span", {}, h("b", {}, t("Your seats so far"))), total)),
      h("p", { class: "ob-small", style: "margin-top:12px" }, t("Friends count up to 50. Prayer logging is counted in the app. Draw on 10 Feb 2027."), " ", h("a", { href: "/ramadan-2027/rules/", target: "_blank", rel: "noopener" }, t("Rules"))),
    ], [
      platform ? h("button", { class: "ob-link", type: "button", onclick: () => go("install") }, t("Back to download")) : null,
    ]);
  },
};

async function signedIn(u) {
  user = u;
  identify(u.uid, u.email);
  await confirm();
}

async function confirm() {
  screenName = "checking";
  render();
  const checkout = JSON.parse(store.get("sa_checkout") || "null");
  const params = new URLSearchParams(location.search);
  const query = new URLSearchParams();
  for (const key of ["subscription_id", "payment_id"]) if (params.get(key)) query.set(key, params.get(key));
  if (checkout?.sessionId) query.set("session_id", checkout.sessionId);
  const started = Date.now();
  const limit = checkout || query.size ? 90_000 : 6_000;
  while (Date.now() - started < limit) {
    try {
      const token = await user.token();
      const { entitlement } = await api(`/api/entitlement?${query}`, { token });
      if (entitlement?.active) {
        if (!store.get(`sa_purchase_${user.uid}`)) {
          store.set(`sa_purchase_${user.uid}`, "1");
          capture("web_purchase_confirmed", { plan: entitlement.plan, seconds_to_confirm: Math.round((Date.now() - started) / 1000), flow: "start" });
        }
        store.del("sa_checkout");
        store.del("sa_discount");
        seats = await api(`/api/seats${store.get("sa_invite") ? `?invite=${encodeURIComponent(store.get("sa_invite"))}` : ""}`, { token }).catch(() => null);
        if (seats?.code) setPersonProps({ challenge_seats: seats.total, challenge_code: seats.code });
        capture("web_challenge_seat_shown", { seats_total: seats?.total ?? null, code: seats?.code ?? null });
        go("seat");
        return;
      }
    } catch (err) {
      console.warn("entitlement check failed", err);
    }
    await new Promise((r) => setTimeout(r, Date.now() - started < 20_000 ? 2000 : 5000));
  }
  go(checkout || query.size ? "pending" : "notpaid");
}

async function boot() {
  captureRef();
  aff = affiliate();
  setLang(initialLang(), { persist: false });
  render();
  config = await loadConfig();
  setLang(initialLang(config.lang), { persist: false });
  root.querySelector("[data-ob-lang]")?.replaceChildren(langSelect(() => render()));
  initAnalytics(config, { page: "start_paid", funnel: "start", country: config.geo?.country, price_tier: config.tier }, { sdk: true });
  try {
    auth = await initAuth(config.firebase);
    user = await auth.ready;
  } catch (err) {
    console.warn("auth unavailable", err);
  }
  if (!user) return go("signin");
  identify(user.uid, user.email);
  await confirm();
}

boot();
