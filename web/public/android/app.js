// Web onboarding for SalahAlarm on Android. Mirrors the iOS quick-start route
// (OnboardingRouter.quickStartRoute): welcome → mechanism → prayers → goals →
// pace → plan → account → paywall, plus the plan-building step from the guided
// variant. Answers are saved to users/{uid} in the iOS format so the Android app
// starts with the same alarms.

import {
  t, h, setLang, initialLang, langSelect, loadConfig, initAnalytics, capture, identify, captureRef,
  device, chromeIntent, api, money, timeIn, icons, store, currentLang,
} from "/assets/common.js";
import { initAuth, authErrorMessage } from "/assets/auth.js";

const ROUTE = ["welcome", "mechanism", "prayers", "goals", "pace", "loading", "plan", "account", "paywall"];
// Exit offers, shown in turn when someone closes the paywall: a discounted weekly
// plan, then a free trial with no card. They sit outside the progress route.
const EXITS = ["offer", "trial"];
const NO_BACK = new Set(["welcome", "loading", "plan", ...EXITS]);
const PRAYERS = [
  { id: "fajr", name: "Fajr", ar: "الفجر" },
  { id: "dhuhr", name: "Dhuhr", ar: "الظهر" },
  { id: "asr", name: "Asr", ar: "العصر" },
  { id: "maghrib", name: "Maghrib", ar: "المغرب" },
  { id: "isha", name: "Isha", ar: "العشاء" },
];
const GOALS = [
  { id: "allahFirst", emoji: "🤲", label: "put Allah first, before my phone" },
  { id: "consistentPrayer", emoji: "🕌", label: "build a consistent prayer habit" },
  { id: "deepenRelationship", emoji: "💚", label: "deepen my relationship with Allah" },
  { id: "fajrMornings", emoji: "☀️", label: "start my day with Fajr" },
  { id: "findPeace", emoji: "🌍", label: "find peace in a chaotic world" },
  { id: "strengthenImaan", emoji: "📿", label: "strengthen my imaan" },
];
const PACES = [
  { level: "extremelyCommitted", emoji: "🔥", strictness: "strict", title: "Strong structure", sub: "Persistent alarms and strict app blocking" },
  { level: "committed", emoji: "🤲", strictness: "moderate", title: "Balanced support", sub: "Consistent reminders with a practical routine" },
  { level: "startingJourney", emoji: "🌱", strictness: "relaxed", title: "Gentle beginning", sub: "Start small and strengthen the habit over time" },
];
const STRICTNESS = {
  strict: { label: "Strict", detail: "Rings until you dismiss it from the prayer flow." },
  moderate: { label: "Moderate", detail: "Lets the alarm expire after 10 minutes if you miss it." },
  relaxed: { label: "Relaxed", detail: "Allows one snooze before asking you to dismiss it." },
};
const STATE_KEY = "sa_web_onboarding_v1";

const app = document.getElementById("app");
const backBtn = document.getElementById("back");
const bar = document.getElementById("progress");

const state = {
  screen: "welcome",
  profile: {
    selectedAlarmPrayers: PRAYERS.map((p) => p.id),
    goals: [],
    commitmentLevel: "unset",
    alarmStrictness: "strict",
    alarmSoundName: "Makkah Adhan Loud",
  },
  plan: "yearly",
  exitsSeen: [],
};
let config = { plans: [], geo: {} };
let auth = null;
let user = null;
let ref = "";
let trialUsed = false; // this account already had its free trial, or a paid plan
let lapsed = false; // a paid plan that has ended: the paywall becomes "renew"
let shownAt = Date.now();

// ---- persistence ---------------------------------------------------------------

function save() {
  store.set(STATE_KEY, JSON.stringify({ screen: state.screen, profile: state.profile, plan: state.plan, exitsSeen: state.exitsSeen }));
}

function restore() {
  const params = new URLSearchParams(location.search);
  // Handoff from an in-app browser to Chrome carries the answers in the URL.
  const carried = params.get("s");
  let saved = null;
  try {
    saved = carried ? JSON.parse(decodeURIComponent(escape(atob(carried)))) : JSON.parse(store.get(STATE_KEY) || "null");
  } catch {
    saved = null;
  }
  if (saved?.profile) Object.assign(state.profile, saved.profile);
  if (saved?.plan && saved.plan !== "weeklyOffer") state.plan = saved.plan;
  if (Array.isArray(saved?.exitsSeen)) state.exitsSeen = saved.exitsSeen;
  const resume = params.get("resume") || (carried ? saved?.screen : null) || saved?.screen;
  if (resume && (ROUTE.includes(resume) || EXITS.includes(resume)) && resume !== "loading") state.screen = resume;
  // Coming back from an abandoned Dodo checkout: show the next exit offer.
  const exit = params.get("exit");
  if (state.screen === "paywall" && EXITS.includes(exit)) state.screen = nextExit(exit) || "paywall";
  if (carried || params.get("resume")) history.replaceState(null, "", location.pathname + (ref ? `?ref=${encodeURIComponent(ref)}` : ""));
}

// ---- navigation -----------------------------------------------------------------

function routeNow() {
  // Signed-in visitors never see the account step.
  return user ? ROUTE.filter((s) => s !== "account") : ROUTE;
}

function go(screen, { push = true } = {}) {
  if (screen === "account" && user) screen = "paywall";
  const leaving = state.screen;
  if (leaving !== screen) capture("web_onboarding_screen_completed", { screen: leaving, seconds_on_screen: Math.round((Date.now() - shownAt) / 1000) });
  state.screen = screen;
  save();
  if (push) history.pushState({ screen }, "");
  render();
}

/** The first exit offer from `from` onwards that hasn't been shown yet. */
function nextExit(from = "offer") {
  return EXITS.slice(EXITS.indexOf(from)).find((e) => !state.exitsSeen.includes(e) && !(e === "trial" && trialUsed)) || null;
}

function closePaywall() {
  const exit = nextExit();
  capture("web_paywall_closed", { next: exit || "none" });
  if (exit) go(exit);
}

function next() {
  const route = routeNow();
  const i = route.indexOf(state.screen);
  go(route[Math.min(i + 1, route.length - 1)]);
}

function back() {
  if (state.screen === "paywall" && nextExit()) return closePaywall();
  const route = routeNow();
  let i = route.indexOf(state.screen) - 1;
  while (i > 0 && (route[i] === "loading")) i--;
  if (i >= 0) go(route[i], { push: false });
}

window.addEventListener("popstate", (e) => {
  const target = e.state?.screen;
  if (target && (ROUTE.includes(target) || EXITS.includes(target)) && target !== "loading") {
    state.screen = target;
    save();
    render();
  } else {
    back();
  }
});

// ---- rendering --------------------------------------------------------------------

function render() {
  const route = routeNow();
  const index = EXITS.includes(state.screen) ? route.length - 1 : Math.max(0, route.indexOf(state.screen));
  bar.style.width = `${Math.round(((index + 1) / route.length) * 100)}%`;
  bar.parentElement.setAttribute("aria-valuenow", String(Math.round(((index + 1) / route.length) * 100)));
  backBtn.style.visibility = NO_BACK.has(state.screen) ? "hidden" : "visible";
  app.replaceChildren(SCREENS[state.screen]());
  window.scrollTo(0, 0);
  shownAt = Date.now();
  capture("web_onboarding_screen_viewed", { screen: state.screen, step_index: index + 1, step_count: route.length });
  if (state.screen === "paywall") capture("web_paywall_viewed", { plans: config.plans.map((p) => `${p.plan}:${p.currency}${p.amount}`).join(","), discount: config.discount?.code || null });
  if (EXITS.includes(state.screen)) {
    if (!state.exitsSeen.includes(state.screen)) state.exitsSeen.push(state.screen);
    save();
    capture(state.screen === "offer" ? "web_exit_offer_viewed" : "web_free_trial_offer_viewed",
      state.screen === "offer" ? { price: config.offer?.amount, currency: config.offer?.currency } : { days: config.freeTrialDays });
  }
}

function screen(body, footer) {
  return h("section", { class: "screen" }, h("div", { class: "screen-body" }, body), footer ? h("div", { class: "footer" }, footer) : null);
}

function primary(label, onclick, { disabled = false, id } = {}) {
  return h("button", { class: "btn btn-primary", type: "button", onclick, disabled, id }, t(label));
}

function svg(markup) {
  const span = document.createElement("span");
  span.innerHTML = markup;
  return span.firstElementChild;
}

function lines(text) {
  return t(text);
}

const SCREENS = {
  welcome() {
    const step = (icon, title, detail) =>
      h("div", { class: "step-row" },
        h("div", { class: "step-icon" }, svg(icon)),
        h("div", {}, h("div", { class: "step-title" }, t(title)), h("div", { class: "step-detail" }, t(detail))));
    return screen([
      h("div", { class: "brand", style: "margin-bottom:18px" },
        h("img", { src: "/assets/img/icon.png", alt: "", width: 38, height: 38, style: "width:38px;height:38px;border-radius:10px" }),
        h("b", { style: "font-size:17px" }, "SalahAlarm")),
      h("p", { class: "eyebrow" }, t("YOUR NEXT SALAH CAN BE DIFFERENT")),
      h("h1", {}, t("Set an alarm you can't dismiss from bed.")),
      h("p", { class: "lede" }, t("SalahAlarm keeps the reminder active until you get up and scan your prayer mat.")),
      h("div", { class: "card tint steps", style: "padding:0 16px" },
        step(icons.bell, "Your prayer alarm rings", "A clear interruption at prayer time"),
        step(icons.walk, "You get up", "No dismissing it half-asleep"),
        step(icons.scan, "Scan your prayer mat", "The alarm stops and your salah is logged")),
    ], [
      primary("set up my first alarm", next),
      h("p", { class: "small center", style: "margin:0" }, t("You can adjust these preferences after setup.")),
    ]);
  },

  mechanism() {
    const step = (n, icon, title, detail) =>
      h("div", { class: "card" },
        h("div", { class: "step-icon square" }, svg(icon)),
        h("div", {},
          h("div", { class: "step-kicker" }, t("STEP %d", n)),
          h("div", { class: "step-title", style: "font-size:17px" }, t(title)),
          h("div", { class: "step-detail", style: "font-size:14px" }, t(detail))));
    return screen([
      h("h1", {}, t("Pray First."), h("br"), h("span", { class: "accent", style: "white-space:pre-line" }, t("Then Unlock\nYour Apps."))),
      h("p", { class: "lede" }, t("A simple loop that turns prayer time into action.")),
      h("div", { class: "mech" },
        step(1, icons.bell, "Prayer time arrives", "A persistent alarm interrupts the scroll."),
        step(2, icons.apps, "Distractions pause", "The apps you choose stay blocked."),
        step(3, icons.scan, "Scan your prayer mat", "The alarm ends, apps unlock, and salah is logged.")),
      h("div", { class: "card tint", style: "margin-top:12px;display:flex;gap:10px;align-items:center;color:var(--green)" },
        svg(icons.seal), h("b", { style: "color:var(--text);font-size:15px" }, t("No complicated setup. Just one clear next step."))),
    ], primary("personalize my plan", next));
  },

  prayers() {
    const selected = new Set(state.profile.selectedAlarmPrayers);
    const all = selected.size === PRAYERS.length;
    const justFajr = selected.size === 1 && selected.has("fajr");
    const set = (ids) => {
      state.profile.selectedAlarmPrayers = PRAYERS.map((p) => p.id).filter((id) => ids.includes(id));
      save();
      render();
    };
    const rtl = document.documentElement.dir === "rtl";
    return screen([
      h("h1", {}, t("Which Prayers Do You Want Alarms For?")),
      h("p", { class: "lede" }, lines("choose the ones you miss most.\nwe'll only ring when you actually need it.")),
      h("div", { class: "pills", role: "group" },
        h("button", { class: "pill", type: "button", "aria-pressed": String(all), onclick: () => set(PRAYERS.map((p) => p.id)) }, t("all five")),
        h("button", { class: "pill", type: "button", "aria-pressed": String(justFajr), onclick: () => set(["fajr"]) }, t("just fajr")),
        h("button", { class: "pill", type: "button", "aria-pressed": String(!all && !justFajr && selected.size > 0), onclick: () => {} }, t("custom"))),
      PRAYERS.map((p) =>
        h("button", {
          class: "option", type: "button", "aria-pressed": String(selected.has(p.id)),
          onclick: () => {
            selected.has(p.id) ? selected.delete(p.id) : selected.add(p.id);
            set([...selected]);
          },
        },
        h("span", { class: "label" }, t(p.name), rtl ? null : h("span", { class: "sub arabic" }, p.ar)),
        h("span", { class: "check" }))),
    ], primary("continue", () => {
      capture("web_prayers_selected", { prayers: state.profile.selectedAlarmPrayers.join(","), count: state.profile.selectedAlarmPrayers.length });
      next();
    }, { disabled: selected.size === 0 }));
  },

  goals() {
    const selected = new Set(state.profile.goals);
    return screen([
      h("h1", {}, t("What Does Consistency Look Like for You?")),
      h("p", { class: "lede" }, lines("choose up to 3.\nwe'll build your habit plan around these.")),
      GOALS.map((g) =>
        h("button", {
          class: "option", type: "button", "aria-pressed": String(selected.has(g.id)),
          onclick: () => {
            if (selected.has(g.id)) selected.delete(g.id);
            else if (selected.size < 3) selected.add(g.id);
            state.profile.goals = GOALS.map((x) => x.id).filter((id) => selected.has(id));
            save();
            render();
          },
        },
        h("span", { class: "emoji" }, g.emoji),
        h("span", { class: "label" }, t(g.label)),
        h("span", { class: "check" }))),
    ], primary("continue", () => {
      capture("web_goals_selected", { goals: state.profile.goals.join(",") });
      next();
    }, { disabled: selected.size === 0 }));
  },

  pace() {
    const days = h("div", { class: "card grid30" }, Array.from({ length: 30 }, (_, i) => h("span", { class: i < 7 ? "on" : "" }, String(i + 1))));
    return screen([
      h("h1", {}, t("Picture 30 Days of Showing Up.")),
      h("p", { class: "lede" }, t("Choose a pace that feels sustainable. It can be changed anytime.")),
      days,
      h("div", { style: "margin-top:14px" },
        PACES.map((p) =>
          h("button", {
            class: "option", type: "button", role: "radio", "aria-checked": String(state.profile.commitmentLevel === p.level),
            onclick: () => {
              state.profile.commitmentLevel = p.level;
              state.profile.alarmStrictness = p.strictness;
              save();
              render();
            },
          },
          h("span", { class: "emoji" }, p.emoji),
          h("span", { class: "label" }, t(p.title), h("span", { class: "sub" }, t(p.sub))),
          h("span", { class: "check" })))),
    ], primary("create my plan", () => {
      capture("web_pace_selected", { commitment: state.profile.commitmentLevel, strictness: state.profile.alarmStrictness });
      next();
    }, { disabled: state.profile.commitmentLevel === "unset" }));
  },

  loading() {
    const ticks = ["✅  setting up alarms for your city", "✅  calibrating your alarm intensity", "✅  preparing your first-week target"]
      .map((s) => h("li", {}, t(s)));
    const el = h("section", { class: "screen" },
      h("div", { class: "loader" },
        h("div", { class: "ring", role: "img", "aria-label": t("loading...") }),
        h("h2", { style: "white-space:pre-line" }, t("We're Building\nYour Prayer Plan...")),
        h("ul", { class: "ticks" }, ticks)));
    ticks.forEach((li, i) => setTimeout(() => li.classList.add("on"), 350 + i * 550));
    setTimeout(() => { if (state.screen === "loading") go("plan", { push: false }); }, 2300);
    return el;
  },

  plan() {
    const first = firstAlarm();
    const strict = STRICTNESS[state.profile.alarmStrictness] || STRICTNESS.strict;
    const goal = GOALS.find((g) => g.id === state.profile.goals[0]);
    const row = (icon, k, v, d) =>
      h("div", { class: "row" },
        h("div", { class: "ic" }, svg(icon)),
        h("div", {}, h("div", { class: "k" }, k), h("div", { class: "v" }, v), d ? h("div", { class: "d" }, d) : null));
    return screen([
      h("span", { class: "badge" }, svg(icons.seal), t("PERSONALIZED PLAN READY")),
      h("h1", {}, t("A Simpler Path Back to Every Salah.")),
      h("p", { class: "lede" }, t("You can adjust these preferences after setup.")),
      h("div", { class: "card summary" },
        first ? row(icons.alarm, t("Your first alarm"), t("%@ at %@", t(first.name), first.time),
          [config.geo?.city, t("Calculated for your location. It keeps ringing until you reach your mat.")].filter(Boolean).join(" · ")) : null,
        row(icons.bell, t("Prayer coverage"), t("%d prayers", state.profile.selectedAlarmPrayers.length),
          state.profile.selectedAlarmPrayers.map((id) => t(PRAYERS.find((p) => p.id === id).name)).join(" · ")),
        row(icons.shield, t("Support level"), t(strict.label), t(strict.detail)),
        row(icons.target, t("Primary goal"), goal ? t(goal.label) : t("build prayer consistency"), t("Your reminders and progress will reinforce this goal."))),
      h("div", { class: "outcomes" },
        h("div", {}, svg(icons.lock), t("Pause distractions")),
        h("div", {}, svg(icons.scan), t("Reach your mat")),
        h("div", {}, svg(icons.flame), t("Build the streak"))),
    ], primary("continue with my plan", next));
  },

  account() {
    let mode = device.android && device.inApp ? "inapp" : "choose";
    const error = h("p", { class: "error", hidden: true, role: "alert" });
    const showError = (msg) => { error.hidden = !msg; error.textContent = msg || ""; };
    const body = h("div");

    const busy = (btn, on) => {
      btn.disabled = on;
      btn.dataset.label ||= btn.textContent;
      btn.replaceChildren(on ? h("span", { class: "spinner" }) : "", on ? t("Signing you in...") : btn.dataset.label);
    };

    const google = h("button", { class: "btn google-btn", type: "button" }, svg(icons.google), t("Continue with Google"));
    google.addEventListener("click", async () => {
      showError(null);
      busy(google, true);
      capture("web_signin_started", { method: "google" });
      try {
        const u = await auth.google();
        if (u) await signedIn(u, "google");
      } catch (err) {
        capture("web_signin_failed", { method: "google", code: err?.code || "unknown" });
        showError(authErrorMessage(err, t));
      } finally {
        busy(google, false);
      }
    });

    const emailForm = () => {
      const name = h("input", { id: "f-name", autocomplete: "name", maxlength: 60 });
      const email = h("input", { id: "f-email", type: "email", autocomplete: "email", inputmode: "email", required: true });
      const password = h("input", { id: "f-password", type: "password", autocomplete: "new-password", minlength: 6, required: true });
      const submit = h("button", { class: "btn btn-primary", type: "submit" }, t("continue"));
      const form = h("form", { novalidate: true },
        h("div", { class: "field" }, h("label", { for: "f-name" }, t("Name")), name),
        h("div", { class: "field" }, h("label", { for: "f-email" }, t("Email")), email),
        h("div", { class: "field" }, h("label", { for: "f-password" }, t("Password")), password),
        submit);
      form.addEventListener("submit", async (e) => {
        e.preventDefault();
        showError(null);
        if (!/^\S+@\S+\.\S+$/.test(email.value.trim())) return showError(t("Please enter a valid email address."));
        if (password.value.length < 6) return showError(t("Use at least 6 characters for your password."));
        busy(submit, true);
        capture("web_signin_started", { method: "email" });
        try {
          const u = await auth.email(email.value.trim(), password.value, name.value.trim());
          await signedIn(u, "email");
        } catch (err) {
          capture("web_signin_failed", { method: "email", code: err?.code || "unknown" });
          showError(authErrorMessage(err, t));
        } finally {
          busy(submit, false);
        }
      });
      return form;
    };

    const draw = () => {
      if (mode === "inapp") {
        const carried = btoa(unescape(encodeURIComponent(JSON.stringify({ screen: "account", profile: state.profile, plan: state.plan }))));
        const target = new URL(`/android/?resume=account&s=${encodeURIComponent(carried)}${ref ? `&ref=${encodeURIComponent(ref)}` : ""}`, location.href).href;
        body.replaceChildren(
          h("p", { class: "notice" }, t("Google sign-in doesn't work inside this app's browser. Open this page in Chrome, or use email.")),
          h("a", { class: "btn btn-primary", href: chromeIntent(target), style: "margin-top:12px", onclick: () => capture("web_open_in_chrome_tapped", { from: device.inApp }) }, t("Open in Chrome")),
          h("div", { class: "divider" }, t("or")),
          emailForm());
      } else if (mode === "email") {
        body.replaceChildren(emailForm(), h("button", { class: "btn-link", type: "button", onclick: () => { mode = "choose"; draw(); } }, t("Continue with Google")));
      } else {
        body.replaceChildren(
          google,
          h("button", { class: "btn btn-secondary", type: "button", style: "margin-top:10px", onclick: () => { mode = "email"; draw(); capture("web_email_option_tapped"); } }, t("Continue with Email")));
      }
    };
    draw();

    return screen([
      h("h1", {}, t("Save your plan")),
      h("p", { class: "lede" }, t("Your plan is ready. Save it to keep your routine with you.")),
      body,
      error,
      h("p", { class: "small", style: "margin-top:16px;display:flex;gap:8px;align-items:flex-start" },
        svg(icons.android), t("Use the same account to sign in to the Android app.")),
    ]);
  },

  paywall() {
    const plans = config.plans?.length ? config.plans : [];
    const first = firstAlarm();
    const error = h("p", { class: "error", hidden: true, role: "alert" });
    const cta = primary("continue", () => startCheckout(cta, error), { disabled: !plans.length, id: "checkout" });
    const weekly = plans.find((p) => p.plan === "weekly");
    const selected = plans.find((p) => p.plan === state.plan) || plans[0];
    if (selected && selected.trialDays > 0) cta.textContent = t("Start my %d-day free trial", selected.trialDays);

    const planCard = (p) => {
      const isYearly = p.plan === "yearly";
      const price = money(p.amount, p.currency);
      const deal = config.discount?.plan === p.plan ? config.discount : null;
      const savePct = isYearly && weekly && weekly.currency === p.currency ? Math.round((1 - p.amount / (weekly.amount * 52)) * 100) : 0;
      return h("button", {
        class: "plan", type: "button", role: "radio", "aria-checked": String(p.plan === state.plan),
        onclick: () => {
          state.plan = p.plan;
          save();
          capture("web_plan_selected", { plan: p.plan, price: p.amount, currency: p.currency });
          render();
        },
      },
      isYearly ? h("span", { class: "flag" }, savePct > 0 ? t("SAVE %d%", savePct) : t("BEST VALUE")) : null,
      h("span", { class: "radio" }),
      h("span", {},
        h("span", { class: "name" }, t(isYearly ? "Yearly plan" : "Weekly")),
        h("span", { class: "meta", style: "display:block" },
          deal ? t("First year %@, then %@ yearly", money(deal.amount, deal.currency), price)
            : p.trialDays > 0 ? t("%d days free, then %@", p.trialDays, price) : t(isYearly ? "Billed %@ annually" : "Billed %@ weekly", price))),
      h("span", { class: "price" },
        t("%@/week", money(isYearly ? p.weeklyEquivalent : p.amount, p.currency))));
    };

    return screen([
      nextExit() ? h("div", { class: "close-row" }, h("button", { class: "close-btn", type: "button", "aria-label": t("Close"), onclick: closePaywall }, "×")) : null,
      first ? h("div", { class: "hero-alarm" },
        svg(icons.alarm),
        h("div", {}, h("div", { class: "k" }, t("Your first alarm")), h("div", { class: "big" }, t("%@ at %@", t(first.name), first.time)),
          config.geo?.city ? h("div", { class: "k" }, config.geo.city) : null)) : null,
      lapsed ? h("p", { class: "notice" }, t("Your plan has ended. Renew to turn your prayer alarms back on.")) : null,
      config.discount ? h("p", { class: "notice" }, t("Your %d% discount is applied to the yearly plan.", config.discount.percentOff)) : null,
      h("h1", {}, t(lapsed ? "Welcome back! Renew SalahAlarm" : "Unlock SalahAlarm for Android")),
      h("ul", { class: "benefits" },
        ["persistent prayer alarms", "mat scan + distraction blocking", "Accurate Local Prayer Times", "streaks, qibla, Quran + widgets"]
          .map((b) => h("li", {}, svg(icons.check), t(b)))),
      plans.length ? h("div", { class: "plans", role: "radiogroup" }, plans.map(planCard)) : h("p", { class: "notice" }, t("loading deals...")),
    ], [
      error,
      cta,
      h("div", { class: "trust" },
        h("span", {}, svg(icons.check), t("Cancel anytime")),
        h("span", {}, svg(icons.card), t("Secure checkout by Dodo Payments"))),
      h("p", { class: "small center", style: "margin:0" }, t("Works on Android 8 and newer")),
      h("div", { class: "links" },
        h("a", { href: "/android/install/" }, t("Already paid? Download the app")),
        h("a", { href: "https://ramadan-pro.lovable.app/privacy", target: "_blank", rel: "noopener" }, t("privacy")),
        h("a", { href: "https://ramadan-pro.lovable.app/terms", target: "_blank", rel: "noopener" }, t("terms"))),
    ]);
  },

  offer() {
    const o = config.offer;
    const error = h("p", { class: "error", hidden: true, role: "alert" });
    const cta = primary(o?.percentOff ? t("Claim my %d% off", o.percentOff) : t("Claim my offer"), () => startCheckout(cta, error, "weeklyOffer"), { disabled: !o, id: "checkout-offer" });
    return screen([
      h("span", { class: "badge" }, svg(icons.seal), t("ONE-TIME OFFER")),
      h("h1", {}, t("Wait! Here's a better price, just for you")),
      h("p", { class: "lede" }, t("We want price to be the last thing between you and Fajr.")),
      o ? h("div", { class: "card offer-card" },
        o.percentOff ? h("div", { class: "offer-off" }, t("%d% OFF", o.percentOff)) : null,
        h("div", { class: "offer-price" },
          o.regularAmount ? h("s", {}, money(o.regularAmount, o.currency)) : null, " ",
          h("b", {}, t("%@/week", money(o.amount, o.currency)))),
        h("div", { class: "small", style: "margin:0" }, t("Billed %@ weekly. Cancel anytime.", money(o.amount, o.currency)))) : h("p", { class: "notice" }, t("loading deals...")),
      h("ul", { class: "benefits", style: "margin-top:16px" },
        ["persistent prayer alarms", "mat scan + distraction blocking", "streaks, qibla, Quran + widgets"]
          .map((b) => h("li", {}, svg(icons.check), t(b)))),
    ], [
      error,
      cta,
      h("button", { class: "btn-link", type: "button", onclick: () => { capture("web_exit_offer_declined"); go(nextExit("trial") || "paywall"); } }, t("No thanks")),
      h("div", { class: "trust" }, h("span", {}, svg(icons.card), t("Secure checkout by Dodo Payments"))),
    ]);
  },

  trial() {
    const days = config.freeTrialDays || 7;
    const error = h("p", { class: "error", hidden: true, role: "alert" });
    const cta = primary(t("Start my %d free days", days), () => startTrial(cta, error), { id: "start-trial" });
    return screen([
      h("div", { class: "moon", "aria-hidden": "true" }, "🌙"),
      h("h1", {}, t("Ramadan is coming. Let's get you ready.")),
      h("p", { class: "lede" }, t("We'd be happy to give you %d days of SalahAlarm for free, so you can build the habit before Ramadan begins.", days)),
      h("div", { class: "card tint" },
        h("ul", { class: "benefits", style: "margin:0" },
          [t("Every feature, free for %d days", days), t("No card needed"), t("Nothing is charged when it ends")]
            .map((b) => h("li", {}, svg(icons.check), b)))),
    ], [
      error,
      cta,
      h("button", { class: "btn-link", type: "button", onclick: () => { capture("web_free_trial_declined"); go("paywall"); } }, t("See plans instead")),
    ]);
  },
};

// ---- plan helpers ----------------------------------------------------------------

function firstAlarm() {
  const s = config.schedule;
  if (!s?.times) return null;
  const now = Date.now();
  const tz = config.geo?.timezone;
  const order = PRAYERS.filter((p) => state.profile.selectedAlarmPrayers.includes(p.id));
  for (const p of order) {
    if (Date.parse(s.times[p.id]) > now) return { name: p.name, time: timeIn(s.times[p.id], tz) };
  }
  const p = order[0];
  return p && s.tomorrow ? { name: p.name, time: timeIn(s.tomorrow[p.id], tz) } : null;
}

// ---- auth + checkout --------------------------------------------------------------

async function signedIn(u, method) {
  user = u;
  identify(u.uid, u.email);
  capture("web_signin_completed", { method, provider: u.provider });
  const token = await u.token();
  // Save answers for the app; do not block the paywall on it.
  api("/api/profile", { method: "POST", token, body: { profile: { ...state.profile, displayName: u.name || "", lastCompletedScreen: "screen17" } } })
    .catch((err) => console.warn("profile save failed", err));
  if (await alreadySubscribed(token)) return;
  go("paywall");
}

// Paying subscribers skip the paywall. Trial users see it (they may want to buy
// now), but not the free-trial offer again.
async function alreadySubscribed(token) {
  try {
    const { entitlement } = await api("/api/entitlement", { token });
    trialUsed = entitlement?.status === "trial" || entitlement?.provider === "dodo";
    lapsed = entitlement?.provider === "dodo" && !entitlement.active;
    if (lapsed) capture("web_renewal_paywall", { status: entitlement.status });
    if (entitlement?.active && entitlement.status !== "trial") {
      capture("web_returning_subscriber", {});
      location.href = "/android/welcome/";
      return true;
    }
  } catch (err) {
    console.warn("entitlement check failed", err);
  }
  return false;
}

async function startCheckout(btn, error, planId) {
  error.hidden = true;
  if (!user) return go("account");
  const label = btn.textContent;
  const plan = planId === "weeklyOffer" ? config.offer : config.plans.find((p) => p.plan === state.plan) || config.plans[0];
  btn.disabled = true;
  btn.replaceChildren(h("span", { class: "spinner" }), t("processing..."));
  capture("web_checkout_started", { plan: plan?.plan, price: plan?.amount, currency: plan?.currency, trial_days: plan?.trialDays || 0 });
  try {
    const token = await user.token();
    const res = await api("/api/checkout", {
      method: "POST",
      token,
      body: { plan: plan.plan, lang: currentLang(), ref, name: user.name || "", discount: config.discount?.code },
    });
    if (res.alreadyActive) {
      location.href = "/android/welcome/";
      return;
    }
    store.set("sa_checkout", JSON.stringify({ sessionId: res.sessionId, plan: plan.plan, at: Date.now() }));
    location.href = res.checkoutUrl;
  } catch (err) {
    capture("web_checkout_failed", { status: err.status || 0, message: err.message });
    error.textContent = err.status === 503
      ? t("Checkout is not available yet. Please try again soon.")
      : navigator.onLine === false ? t("No internet connection. Please try again.") : t("Something went wrong. Please try again.");
    error.hidden = false;
    btn.disabled = false;
    btn.replaceChildren(label);
  }
}

async function startTrial(btn, error) {
  error.hidden = true;
  if (!user) return go("account");
  const label = btn.textContent;
  btn.disabled = true;
  btn.replaceChildren(h("span", { class: "spinner" }), t("processing..."));
  try {
    const { entitlement } = await api("/api/trial", { method: "POST", token: await user.token() });
    capture("web_free_trial_started", { days: config.freeTrialDays, until: entitlement?.accessUntil });
    location.href = "/android/welcome/?trial=1";
  } catch (err) {
    capture("web_free_trial_failed", { status: err.status || 0 });
    error.textContent = err.status === 409
      ? t("This account has already used its free trial. Pick a plan to keep going.")
      : navigator.onLine === false ? t("No internet connection. Please try again.") : t("Something went wrong. Please try again.");
    error.hidden = false;
    btn.disabled = false;
    btn.replaceChildren(label);
    if (err.status === 409) setTimeout(() => go("paywall"), 2500);
  }
}

// ---- boot -------------------------------------------------------------------------

async function boot() {
  ref = captureRef();
  setLang(initialLang(), { persist: false });
  backBtn.innerHTML = icons.back;
  backBtn.addEventListener("click", back);
  restore();

  config = await loadConfig();
  if (config.discount) state.plan = config.discount.plan;
  setLang(initialLang(config.lang), { persist: false });
  document.getElementById("lang").replaceWith(langSelect(() => render()));
  initAnalytics(config, { ref, page: "android_onboarding", country: config.geo?.country, price_tier: config.tier, funnel: "android_web" });

  if (!store.get("sa_onboarding_started")) {
    store.set("sa_onboarding_started", "1");
    capture("web_onboarding_started", { landing_screen: state.screen });
  }

  try {
    auth = await initAuth(config.firebase);
    user = await auth.ready;
    if (user) identify(user.uid, user.email);
    // Returning from a redirect sign-in lands on the account screen while signed in.
    if (user && state.screen === "account") {
      await signedIn(user, user.provider === "password" ? "email" : "google");
      return;
    }
  } catch (err) {
    console.warn("auth unavailable", err);
  }
  if ((state.screen === "paywall" || EXITS.includes(state.screen)) && !user) state.screen = "account";
  if (user && (state.screen === "paywall" || EXITS.includes(state.screen))) {
    if (await alreadySubscribed(await user.token())) return;
    if (state.screen === "trial" && trialUsed) state.screen = "paywall";
  }
  history.replaceState({ screen: state.screen }, "");
  render();
}

boot();
