// After checkout (/android/welcome/) and for reinstalls (/android/install/):
// confirm the purchase, download the APK, and walk through sideloading and the
// alarm-reliability settings Android needs.

import {
  t, h, setLang, initialLang, langSelect, loadConfig, initAnalytics, capture, identify, captureRef,
  device, chromeIntent, api, icons, store,
} from "/assets/common.js";
import { initAuth } from "/assets/auth.js";

const mode = document.body.dataset.mode; // "welcome" | "install"
const app = document.getElementById("app");
const APK = "/download/salahalarm.apk";

let config = {};
let user = null;
let status = mode === "welcome" ? "checking" : "install"; // checking | active | pending | signin | install
let apk = { versionName: null, sizeMb: null };
let appLogin = null; // intent link that opens the installed app already signed in

function svg(markup) {
  const span = document.createElement("span");
  span.innerHTML = markup;
  return span.firstElementChild;
}

// ---- payment confirmation ------------------------------------------------------

async function confirmPayment() {
  const checkout = JSON.parse(store.get("sa_checkout") || "null");
  const params = new URLSearchParams(location.search);
  const query = new URLSearchParams();
  for (const key of ["subscription_id", "payment_id"]) if (params.get(key)) query.set(key, params.get(key));
  if (checkout?.sessionId) query.set("session_id", checkout.sessionId);

  const started = Date.now();
  while (Date.now() - started < 90_000) {
    try {
      const token = await user.token();
      const { entitlement } = await api(`/api/entitlement?${query}`, { token });
      if (entitlement?.active) {
        status = "active";
        if (!store.get(`sa_purchase_${user.uid}`)) {
          store.set(`sa_purchase_${user.uid}`, "1");
          capture("web_purchase_confirmed", { plan: entitlement.plan, seconds_to_confirm: Math.round((Date.now() - started) / 1000) });
        }
        store.del("sa_checkout");
        render();
        autoDownload();
        return;
      }
    } catch (err) {
      console.warn("entitlement check failed", err);
    }
    await new Promise((r) => setTimeout(r, Date.now() - started < 20_000 ? 2000 : 5000));
  }
  status = "pending";
  capture("web_purchase_pending_timeout", {});
  render();
}

function autoDownload() {
  // Start the download once, right after payment, as long as Chrome can take it.
  if (!device.android || device.inApp || store.get("sa_auto_downloaded")) return;
  store.set("sa_auto_downloaded", "1");
  capture("apk_download_auto_started", { mode });
  setTimeout(() => {
    const a = h("a", { href: APK, download: "SalahAlarm.apk", hidden: true });
    document.body.append(a);
    a.click();
    a.remove();
  }, 1200);
}

// A fresh one-time code is fetched ahead of the tap, because Chrome only follows
// intent links straight from a user gesture.
async function prepareAppLogin() {
  if (!user || !device.android || device.inApp) return;
  try {
    const { code } = await api("/api/app-login", { method: "POST", token: await user.token() });
    const fallback = encodeURIComponent(new URL("/android/install/", location.href).href);
    appLogin = `intent://login?code=${code}#Intent;scheme=salahalarm;package=com.salahalarm.android;S.browser_fallback_url=${fallback};end`;
    render();
  } catch (err) {
    console.warn("app login link unavailable", err);
  }
  setTimeout(prepareAppLogin, 20 * 60 * 1000);
}

// ---- rendering --------------------------------------------------------------------

function header() {
  if (status === "checking") {
    return [
      h("h1", { style: "margin-top:12px" }, t("Confirming your payment…")),
      h("p", { class: "status-line" }, h("span", { class: "mini-ring" }), t("This usually takes a few seconds.")),
    ];
  }
  if (status === "signin") {
    return [
      h("h1", { style: "margin-top:12px" }, t("Sign in to see your purchase")),
      h("p", { class: "lede" }, t("Use the account you created during setup.")),
      h("a", { class: "btn btn-primary", href: "/android/?resume=account" }, t("sign in")),
    ];
  }
  if (status === "active") {
    return [
      h("div", { class: "success-mark" }, svg(icons.check)),
      h("h1", { class: "center" }, t("You're in! Let's install SalahAlarm")),
      h("p", { class: "lede center" }, t("Payment confirmed. Two minutes from now your first alarm is set.")),
    ];
  }
  if (status === "pending") {
    return [
      h("h1", { style: "margin-top:12px" }, t("Install SalahAlarm for Android")),
      h("p", { class: "notice" }, t("Your payment is still processing. You can install the app now; it unlocks as soon as the payment clears.")),
    ];
  }
  return [
    h("h1", { style: "margin-top:12px" }, t("Install SalahAlarm for Android")),
    h("p", { class: "lede" }, t("Download the app, then sign in with the account you subscribed with.")),
  ];
}

function downloadBlock() {
  if (!device.android) {
    return h("div", { class: "card tint" },
      h("b", {}, t("Open this page on your Android phone")),
      h("p", { class: "small", style: "margin:6px 0 0" }, "salahalarm.com/android/install"));
  }
  if (device.inApp) {
    return h("div", {},
      h("p", { class: "notice" }, t("Downloads don't work inside this app's browser. Open this page in Chrome to download.")),
      h("a", {
        class: "btn btn-primary", style: "margin-top:12px",
        href: chromeIntent(new URL("/android/install/", location.href).href),
        onclick: () => capture("web_open_in_chrome_tapped", { from: device.inApp, page: mode }),
      }, t("Open in Chrome")));
  }
  const label = apk.sizeMb ? t("Download SalahAlarm (%@ MB)", apk.sizeMb) : t("Download SalahAlarm");
  return h("div", {},
    h("a", {
      class: "btn btn-primary", href: APK, download: "SalahAlarm.apk",
      onclick: () => capture("apk_download_tapped", { mode, status }),
    }, svg(icons.download), label),
    apk.versionName ? h("p", { class: "small center", style: "margin:6px 0 0" }, t("Version %@ · Android 8 or newer", apk.versionName)) : null);
}

function guide() {
  const email = user?.email;
  const step = (title, text, mock) => h("li", {}, h("div", {}, h("h3", {}, t(title)), h("p", {}, text), mock || null));
  const mock = (...rows) => h("div", { class: "mock", "aria-hidden": "true" }, rows);
  const row = (...cells) => h("div", { class: "row" }, cells);
  return h("ol", { class: "guide" },
    step("Download the app",
      t("If Chrome asks, tap Download anyway. Chrome shows this for every app that comes from a website instead of Google Play."),
      mock(h("b", {}, "SalahAlarm.apk"), row(h("span", {}, t("File might be harmful")), h("span", { class: "fake-btn hl" }, t("Download anyway"))))),
    step("Open the file",
      t("Tap Open when the download finishes, or find SalahAlarm.apk in Files › Downloads.")),
    step("Allow installs from Chrome",
      t("If your phone asks, tap Settings, turn on Allow from this source, then go back."),
      mock(row(h("span", {}, t("Allow from this source")), h("span", { class: "toggle" })))),
    step("Tap Install",
      t("If Play Protect warns you, tap More details, then Install anyway. It appears because the app is new and not on Google Play yet."),
      mock(h("b", {}, t("Unsafe app blocked")), row(h("span", { class: "fake-btn hl" }, t("More details")), "→", h("span", { class: "fake-btn hl" }, t("Install anyway"))))),
    step("Open SalahAlarm and sign in",
      email ? t("Use the same account: %@", email) : t("Use the same Google account or email you used here."),
      appLogin ? h("a", {
        class: "btn btn-secondary", style: "margin-top:10px", href: appLogin,
        onclick: () => capture("android_app_login_link_tapped", { mode }),
      }, t("Open SalahAlarm, signed in")) : null),
    step("Finish the 1-minute setup",
      t("Allow notifications and alarms, and turn off battery optimization so Fajr always rings.")));
}

function brandTips() {
  const tips = [
    ["Xiaomi, Redmi, POCO", "Settings › Apps › SalahAlarm: turn on Autostart and set Battery saver to No restrictions."],
    ["Samsung", "Settings › Battery › Background usage limits: add SalahAlarm to Never sleeping apps."],
    ["Oppo, Realme, Vivo, OnePlus", "Settings › Battery › SalahAlarm: allow background activity and auto-launch."],
    ["Huawei, Honor", "Settings › Battery › App launch: set SalahAlarm to Manage manually and turn on all switches."],
  ];
  return h("div", {},
    h("h2", { style: "margin-top:26px" }, t("Alarms not ringing on time?")),
    h("p", { class: "small", style: "margin-top:0" }, t("Some phones stop apps in the background to save battery. Allow SalahAlarm once:")),
    tips.map(([brand, tip]) => h("details", { class: "brand-tip" }, h("summary", {}, brand), h("p", {}, t(tip)))));
}

function render() {
  app.replaceChildren(
    h("div", { class: "screen-body" },
      header(),
      status === "checking" || status === "signin" ? null : [
        h("div", { style: "margin:18px 0 22px" }, downloadBlock()),
        guide(),
        brandTips(),
        h("p", { class: "small center", style: "margin-top:26px" },
          t("Need help?"), " ",
          h("a", { href: "https://ramadan-pro.lovable.app/support", target: "_blank", rel: "noopener" }, t("Contact support"))),
      ]));
}

// ---- boot ---------------------------------------------------------------------------

async function boot() {
  const ref = captureRef();
  setLang(initialLang(), { persist: false });
  render();
  config = await loadConfig();
  setLang(initialLang(config.lang), { persist: false });
  document.getElementById("lang").replaceWith(langSelect(() => render()));
  initAnalytics(config, { ref, page: `android_${mode}`, country: config.geo?.country, funnel: "android_web" });
  capture(mode === "welcome" ? "web_checkout_returned" : "install_guide_viewed", {});

  api("/api/android/latest").then(async (latest) => {
    apk.versionName = latest.versionName;
    const head = await fetch(APK, { method: "HEAD" }).catch(() => null);
    const bytes = Number(head?.headers.get("content-length") || 0);
    if (bytes) apk.sizeMb = (bytes / 1048576).toFixed(1);
    render();
  }).catch(() => {});

  try {
    const auth = await initAuth(config.firebase);
    user = await auth.ready;
    if (user) identify(user.uid, user.email);
  } catch (err) {
    console.warn("auth unavailable", err);
  }

  prepareAppLogin();
  if (mode === "welcome") {
    if (!user) {
      status = "signin";
      render();
      return;
    }
    confirmPayment();
  } else {
    render();
  }
}

boot();
