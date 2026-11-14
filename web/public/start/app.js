// salahalarm.com onboarding: the home page (/) and /start/ both run this.
//
// Storyline (research notes in the project thread, 13 Nov 2026): ask about the pain,
// confirm "you're not alone", show the mechanism, personalise, project the result to
// Ramadan, commit, build the plan, then account, then a hard paywall that repeats the
// story. Every screen is a PostHog funnel step (session replay on), mirrored to
// Firebase Analytics. Answers are saved to users/{uid} in the iOS format.

import {
  t, h, setLang, initialLang, langSelect, loadConfig, initAnalytics, capture, identify, captureRef,
  device, chromeIntent, api, money, timeIn, icons, store, currentLang, affiliate, affiliateBeacon, setPersonProps,
} from "/assets/common.js";
import { initAuth, authErrorMessage } from "/assets/auth.js";

const RAMADAN = "2027-02-08T00:00:00Z"; // expected first day of Ramadan 2027
const STATE_KEY = "sa_start_v1";

const PRAYERS = [
  { id: "fajr", name: "Fajr", ar: "الفجر" },
  { id: "dhuhr", name: "Dhuhr", ar: "الظهر" },
  { id: "asr", name: "Asr", ar: "العصر" },
  { id: "maghrib", name: "Maghrib", ar: "المغرب" },
  { id: "isha", name: "Isha", ar: "العشاء" },
];
const GOALS = [
  { id: "fajrMornings", emoji: "☀️", label: "start my day with Fajr" },
  { id: "consistentPrayer", emoji: "🕌", label: "build a consistent prayer habit" },
  { id: "allahFirst", emoji: "🤲", label: "put Allah first, before my phone" },
  { id: "deepenRelationship", emoji: "💚", label: "deepen my relationship with Allah" },
  { id: "strengthenImaan", emoji: "📿", label: "strengthen my imaan" },
  { id: "findPeace", emoji: "🌍", label: "find peace in a chaotic world" },
];
const APPS = [
  { id: "tiktok", name: "TikTok", bg: "#111", l: "♪" },
  { id: "instagram", name: "Instagram", bg: "linear-gradient(45deg,#f9a825,#e1306c,#8e24aa)", l: "◎" },
  { id: "youtube", name: "YouTube", bg: "#e53935", l: "▶" },
  { id: "snapchat", name: "Snapchat", bg: "#f7d618", l: "👻" },
  { id: "whatsapp", name: "WhatsApp", bg: "#25d366", l: "✆" },
  { id: "x", name: "X", bg: "#000", l: "𝕏" },
  { id: "games", name: "Games", bg: "#5c6bc0", l: "🎮" },
  { id: "netflix", name: "Netflix", bg: "#b71c1c", l: "N" },
];

// The route. `kind` drives analytics (question / insight / motion / setup / account / paywall).
const ROUTE = [
  "welcome", "missFajr", "whatHappens", "notAlone", "yesterday", "feeling", "reminder",
  "mechanism", "distractions", "salahlock", "prayers", "sleeper", "goals", "ramadanGoal",
  "projection", "proof", "commit", "building", "plan", "seat", "account", "paywall",
];
const EXITS = ["offer"];
const NO_BACK = new Set(["welcome", "building", "plan", ...EXITS]);
const NIGHT = new Set(["welcome", "notAlone", "reminder", "building", "seat"]);

const root = document.getElementById("ob");
const app = root.querySelector("[data-ob-app]");
const backBtn = root.querySelector("[data-ob-back]");
const bar = root.querySelector("[data-ob-progress]");

const state = {
  screen: "welcome",
  a: {
    missFajr: null, whatHappens: [], yesterday: null, feeling: null, distractions: [],
    sleeper: null, ramadanGoal: null, committed: false,
  },
  profile: {
    selectedAlarmPrayers: PRAYERS.map((p) => p.id),
    goals: [],
    commitmentLevel: "committed",
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
let aff = "";
let lapsed = false;
let shownAt = Date.now();
let joined = null; // challenge joiners, from /ramadan-2027/stats.json
const timers = new Set();

// ---- persistence ---------------------------------------------------------------

function save() {
  store.set(STATE_KEY, JSON.stringify({ screen: state.screen, a: state.a, profile: state.profile, plan: state.plan, exitsSeen: state.exitsSeen }));
}

function restore() {
  const params = new URLSearchParams(location.search);
  const carried = params.get("s");
  let saved = null;
  try {
    saved = carried ? JSON.parse(decodeURIComponent(escape(atob(carried)))) : JSON.parse(store.get(STATE_KEY) || "null");
  } catch {
    saved = null;
  }
  if (saved?.a) Object.assign(state.a, saved.a);
  if (saved?.profile) Object.assign(state.profile, saved.profile);
  if (saved?.plan && saved.plan !== "weeklyOffer") state.plan = saved.plan;
  if (Array.isArray(saved?.exitsSeen)) state.exitsSeen = saved.exitsSeen;
  const resume = params.get("resume") || saved?.screen;
  if (resume && (ROUTE.includes(resume) || EXITS.includes(resume)) && resume !== "building") state.screen = resume;
  const exit = params.get("exit");
  if (state.screen === "paywall" && exit === "offer" && !state.exitsSeen.includes("offer")) state.screen = "offer";
  if (carried || params.get("resume") || params.get("exit")) {
    const keep = new URLSearchParams();
    for (const k of ["ref", "via", "lang"]) if (params.get(k)) keep.set(k, params.get(k));
    history.replaceState(null, "", location.pathname + (keep.size ? `?${keep}` : "") + location.hash);
  }
}

// ---- navigation -----------------------------------------------------------------

const routeNow = () => (user ? ROUTE.filter((s) => s !== "account") : ROUTE);

function go(screen, { push = true } = {}) {
  if (screen === "account" && user) screen = "paywall";
  const leaving = state.screen;
  if (leaving !== screen) {
    const route = routeNow();
    capture("web_onboarding_screen_completed", {
      screen: leaving, index: route.indexOf(leaving) + 1, duration_ms: Date.now() - shownAt,
      seconds_on_screen: Math.round((Date.now() - shownAt) / 1000), answer: answerOf(leaving),
    });
  }
  state.screen = screen;
  save();
  if (push) history.pushState({ screen }, "");
  render();
}

function next() {
  const route = routeNow();
  go(route[Math.min(route.indexOf(state.screen) + 1, route.length - 1)]);
}

function back() {
  if (state.screen === "paywall" && !state.exitsSeen.includes("offer")) return closePaywall();
  const route = routeNow();
  let i = route.indexOf(state.screen) - 1;
  while (i > 0 && route[i] === "building") i--;
  if (i >= 0) go(route[i], { push: false });
}

function closePaywall() {
  const offer = !state.exitsSeen.includes("offer") && config.offer;
  capture("web_paywall_closed", { next: offer ? "offer" : "none" });
  if (offer) go("offer");
}

window.addEventListener("popstate", (e) => {
  const target = e.state?.screen;
  if (target && (ROUTE.includes(target) || EXITS.includes(target)) && target !== "building") {
    state.screen = target;
    save();
    render();
  } else back();
});

function answerOf(screen) {
  const v = { ...state.a, prayers: state.profile.selectedAlarmPrayers, goals: state.profile.goals, pace: state.profile.commitmentLevel }[screen];
  if (v == null) return null;
  return Array.isArray(v) ? v.join(",") : String(v);
}

// ---- rendering --------------------------------------------------------------------

function render() {
  for (const id of timers) clearTimeout(id);
  timers.clear();
  const route = routeNow();
  const index = EXITS.includes(state.screen) ? route.length - 1 : Math.max(0, route.indexOf(state.screen));
  const pct = Math.round(((index + 1) / route.length) * 100);
  bar.style.width = `${pct}%`;
  bar.parentElement.setAttribute("aria-valuenow", String(pct));
  backBtn.style.visibility = NO_BACK.has(state.screen) ? "hidden" : "visible";
  root.dataset.theme = NIGHT.has(state.screen) ? "night" : "day";
  root.dataset.screen = state.screen;
  app.replaceChildren(SCREENS[state.screen]());
  if (root.getBoundingClientRect().top < 0) root.scrollIntoView({ block: "start" });
  shownAt = Date.now();
  capture("web_onboarding_screen_viewed", { screen: state.screen, index: index + 1, total: route.length, step_index: index + 1, step_count: route.length });
  if (state.screen === "paywall") {
    capture("web_paywall_viewed", { tier: config.tier, currency: config.plans?.[0]?.currency, plans: (config.plans || []).map((p) => `${p.plan}:${p.currency}${p.amount}`).join(","), flow: "start" });
  }
  if (state.screen === "offer") {
    if (!state.exitsSeen.includes("offer")) state.exitsSeen.push("offer");
    save();
    capture("web_exit_offer_viewed", { price: config.offer?.amount, currency: config.offer?.currency, flow: "start" });
  }
}

const later = (fn, ms) => { const id = setTimeout(() => { timers.delete(id); fn(); }, ms); timers.add(id); return id; };

function screen(body, footer) {
  return h("section", { class: "ob-screen" }, h("div", { class: "ob-body" }, body), footer ? h("div", { class: "ob-foot" }, footer) : null);
}

function primary(label, onclick, { disabled = false, id } = {}) {
  return h("button", { class: "ob-btn ob-btn-primary", type: "button", onclick, disabled, id, "data-ob-cta": "primary" }, t(label));
}

function svg(markup) {
  const span = document.createElement("span");
  span.innerHTML = markup;
  return span.firstElementChild;
}

const title = (text, accent) => h("h1", { class: "ob-h1" }, t(text), accent ? [" ", h("em", {}, t(accent))] : null);
const lede = (text) => h("p", { class: "ob-lede" }, t(text));
const kicker = (text) => h("p", { class: "ob-kicker" }, t(text));

/** Single-choice question: tap an answer and move on. */
function single(key, options, { after } = {}) {
  return h("div", { class: "ob-options", role: "radiogroup" }, options.map((o) =>
    h("button", {
      class: "ob-opt", type: "button", role: "radio", "aria-checked": String(state.a[key] === o.id),
      onclick: (e) => {
        state.a[key] = o.id;
        save();
        e.currentTarget.setAttribute("aria-checked", "true");
        capture("web_onboarding_answer", { screen: state.screen, question: key, answer: o.id });
        later(() => (after ? after(o) : next()), 260);
      },
    },
    o.emoji ? h("span", { class: "ob-emoji" }, o.emoji) : null,
    h("span", { class: "ob-label" }, t(o.label), o.sub ? h("span", { class: "ob-sub" }, t(o.sub)) : null),
    h("span", { class: "ob-tick" }))));
}

/** Multi-choice question with a continue button. */
function multi(key, options, { max = 99 } = {}) {
  const selected = new Set(state.a[key]);
  const cta = primary("continue", () => {
    capture("web_onboarding_answer", { screen: state.screen, question: key, answer: state.a[key].join(","), count: state.a[key].length });
    next();
  }, { disabled: selected.size === 0 });
  const list = h("div", { class: "ob-options", role: "group" }, options.map((o) =>
    h("button", {
      class: "ob-opt", type: "button", "aria-pressed": String(selected.has(o.id)),
      onclick: (e) => {
        if (selected.has(o.id)) selected.delete(o.id);
        else if (selected.size < max) selected.add(o.id);
        state.a[key] = options.map((x) => x.id).filter((id) => selected.has(id));
        save();
        for (const btn of list.children) btn.setAttribute("aria-pressed", String(selected.has(btn.dataset.id)));
        cta.disabled = selected.size === 0;
        e.currentTarget.blur();
      },
      "data-id": o.id,
    },
    o.emoji ? h("span", { class: "ob-emoji" }, o.emoji) : null,
    h("span", { class: "ob-label" }, t(o.label), o.sub ? h("span", { class: "ob-sub" }, t(o.sub)) : null),
    h("span", { class: "ob-tick" }))));
  return { list, cta };
}

function daysToRamadan() {
  return Math.max(0, Math.ceil((Date.parse(RAMADAN) - Date.now()) / 86400000));
}

const SCREENS = {
  // 1. Hook: a ringing Fajr alarm you can't swipe away.
  welcome() {
    const first = firstAlarm(["fajr"]);
    return screen([
      h("div", { class: "ob-hero", "aria-hidden": "true" },
        h("div", { class: "ob-stars" }), h("div", { class: "ob-moon" }), h("div", { class: "ob-sunrise" }),
        h("div", { class: "ob-rings" }, h("i"), h("i"), h("i")),
        h("div", { class: "ob-phone" }, h("div", {},
          h("div", { class: "n" }, "FAJR"),
          h("div", { class: "t" }, first?.time || "5:12"),
          h("div", { class: "b" }, t("Scan your prayer mat")),
          h("div", { class: "x" }, t("slide to snooze"))))),
      h("p", { class: "ob-chip", style: "margin-bottom:12px" }, "🌙 ", t("%d days until Ramadan", daysToRamadan())),
      title("Never miss Fajr", "again."),
      lede("The prayer alarm that only stops when you reach your prayer mat. Answer a few questions and we'll build your plan."),
    ], [
      primary("Build my prayer plan", next),
      h("p", { class: "ob-small ob-center" }, "★★★★★ ", t("Rated 4.8 on the App Store")),
      h("a", { class: "ob-link ob-center", href: "/start/paid/", style: "display:block" }, t("Already paid? Get the app")),
    ]);
  },

  // 2-3. The pain.
  missFajr() {
    return screen([
      kicker("Question 1"),
      title("How often do you miss Fajr?"),
      lede("Be honest. Nobody sees this but you."),
      single("missFajr", [
        { id: "daily", emoji: "😔", label: "Almost every day" },
        { id: "often", emoji: "😕", label: "A few times a week" },
        { id: "sometimes", emoji: "🙂", label: "Sometimes" },
        { id: "rarely", emoji: "💪", label: "Rarely, I want to stay consistent" },
      ]),
    ]);
  },

  whatHappens() {
    const { list, cta } = multi("whatHappens", [
      { id: "offHalfAsleep", emoji: "📵", label: "I switch it off half asleep" },
      { id: "snooze", emoji: "😴", label: "I snooze again and again" },
      { id: "dontHear", emoji: "🔇", label: "I don't hear it at all" },
      { id: "lateNight", emoji: "🌙", label: "I go to sleep too late" },
      { id: "awakeNoMove", emoji: "🛏️", label: "I'm awake but can't get up" },
      { id: "phone", emoji: "📱", label: "I pick up my phone and scroll" },
    ]);
    return screen([kicker("Question 2"), title("What happens when your alarm rings?"), lede("Choose all that apply."), list], cta);
  },

  // 4. Confirmation: you're not alone (motion: swipe vs scan).
  notAlone() {
    return screen([
      kicker("You're not alone"),
      title("It's not you.", "It's the alarm."),
      lede("A normal alarm is built to be switched off from bed, so half asleep you always win. Salah Alarm only stops once you're standing at your prayer mat."),
      h("div", { class: "ob-versus" },
        h("div", { class: "ob-vs bad" }, h("span", { class: "big" }, "👉📱"), t("Normal alarm: one swipe and it's gone")),
        h("div", { class: "ob-vs good" }, h("span", { class: "big" }, "🧎"), t("Salah Alarm: rings until you reach the mat"))),
    ], primary("That's me", next));
  },

  // 5. Baseline (motion: five dots fill).
  yesterday() {
    const v = state.a.yesterday;
    const dots = h("div", { class: "ob-dots", "aria-hidden": "true" }, PRAYERS.map((p, i) => h("div", { class: `ob-dot${v != null && i < v ? " on" : ""}` }, t(p.name))));
    const cta = primary("continue", () => {
      capture("web_onboarding_answer", { screen: "yesterday", question: "yesterday", answer: String(state.a.yesterday) });
      next();
    }, { disabled: v == null });
    return screen([
      kicker("Question 3"),
      title("How many prayers did you pray on time yesterday?"),
      dots,
      h("div", { class: "ob-count", role: "radiogroup" }, [0, 1, 2, 3, 4, 5].map((n) =>
        h("button", {
          type: "button", "aria-pressed": String(v === n),
          onclick: () => {
            state.a.yesterday = n;
            save();
            [...dots.children].forEach((d, i) => d.classList.toggle("on", i < n));
            [...dots.parentElement.querySelectorAll(".ob-count button")].forEach((b, i) => b.setAttribute("aria-pressed", String(i === n)));
            cta.disabled = false;
          },
        }, String(n)))),
      h("p", { class: "ob-small ob-center", style: "margin-top:14px" }, t("We'll use this as your starting point.")),
    ], cta);
  },

  feeling() {
    return screen([
      kicker("Question 4"),
      title("How do you feel when you miss a prayer?"),
      single("feeling", [
        { id: "guilty", emoji: "😞", label: "Guilty, it stays with me all day" },
        { id: "distant", emoji: "🌫️", label: "Distant from Allah" },
        { id: "frustrated", emoji: "😤", label: "Frustrated with myself" },
        { id: "numb", emoji: "😶", label: "I've got used to it, and that worries me" },
      ]),
    ]);
  },

  // 7. Confirmation with an ayah.
  reminder() {
    return screen([
      kicker("A reminder"),
      title("That feeling is a good sign."),
      lede("It means your heart still wants to answer the call. You don't need more willpower at 5am. You need a system that does the hard part for you."),
      h("blockquote", { class: "ob-quote" },
        t("“Indeed, prayer has been decreed upon the believers at specified times.”"),
        h("cite", {}, t("Quran 4:103"))),
    ], primary("Show me how", next));
  },

  // 8. Mechanism (motion: the three steps light up in a loop).
  mechanism() {
    const steps = [
      [icons.bell, "The adhan rings at the exact time", "Calculated for your city, every day."],
      [icons.walk, "You get up", "There's no snooze button to hit half asleep."],
      [icons.scan, "Scan your prayer mat", "The alarm stops and your prayer is logged."],
    ].map(([ic, a, b]) => h("div", { class: "ob-step" }, h("div", { class: "ic" }, svg(ic)), h("div", {}, h("div", { class: "tt" }, t(a)), h("div", { class: "dd" }, t(b)))));
    let i = 0;
    const tick = () => { steps.forEach((s, j) => s.classList.toggle("on", j === i % 3)); i++; later(tick, 1300); };
    later(tick, 150);
    return screen([
      kicker("How Salah Alarm works"),
      title("From asleep to your prayer mat", "in 3 steps."),
      h("div", { class: "ob-loop" }, steps),
    ], primary("continue", next));
  },

  distractions() {
    const selected = new Set(state.a.distractions);
    const cta = primary("continue", () => {
      capture("web_onboarding_answer", { screen: "distractions", question: "distractions", answer: state.a.distractions.join(","), count: state.a.distractions.length });
      next();
    }, { disabled: selected.size === 0 });
    const grid = h("div", { class: "ob-apps" }, APPS.map((a) =>
      h("button", {
        class: "ob-app", type: "button", "aria-pressed": String(selected.has(a.id)),
        onclick: (e) => {
          selected.has(a.id) ? selected.delete(a.id) : selected.add(a.id);
          state.a.distractions = APPS.map((x) => x.id).filter((id) => selected.has(id));
          save();
          e.currentTarget.setAttribute("aria-pressed", String(selected.has(a.id)));
          cta.disabled = selected.size === 0;
        },
      }, h("span", { class: "logo", style: `background:${a.bg}` }, a.l), a.name)));
    return screen([
      kicker("Question 5"),
      title("Which apps pull you away from prayer?"),
      lede("Tap all that apply."),
      grid,
    ], cta);
  },

  // 10. Value of SalahLock with their own apps (motion: icons lock one by one).
  salahlock() {
    const chosen = APPS.filter((a) => state.a.distractions.includes(a.id)).slice(0, 6);
    return screen([
      kicker("SalahLock"),
      title("Your apps wait until you've prayed."),
      lede("When prayer time comes, SalahLock pauses the apps you picked. Scan your mat after you pray and they unlock."),
      h("div", { class: "ob-locked" }, (chosen.length ? chosen : APPS.slice(0, 3)).map((a, i) =>
        h("div", { class: "ob-app", style: `animation-delay:${0.2 + i * 0.25}s` }, h("span", { class: "logo", style: `background:${a.bg}` }, a.l), a.name))),
      h("p", { class: "ob-small ob-center" }, t("You choose which apps, and how strict.")),
    ], primary("I want this", next));
  },

  prayers() {
    const selected = new Set(state.profile.selectedAlarmPrayers);
    const cta = primary("continue", () => {
      capture("web_prayers_selected", { prayers: state.profile.selectedAlarmPrayers.join(","), count: state.profile.selectedAlarmPrayers.length });
      next();
    }, { disabled: selected.size === 0 });
    const rtl = document.documentElement.dir === "rtl";
    const list = h("div", { class: "ob-options" }, PRAYERS.map((p) =>
      h("button", {
        class: "ob-opt", type: "button", "aria-pressed": String(selected.has(p.id)),
        onclick: (e) => {
          selected.has(p.id) ? selected.delete(p.id) : selected.add(p.id);
          state.profile.selectedAlarmPrayers = PRAYERS.map((x) => x.id).filter((id) => selected.has(id));
          save();
          e.currentTarget.setAttribute("aria-pressed", String(selected.has(p.id)));
          cta.disabled = selected.size === 0;
        },
      },
      h("span", { class: "ob-label" }, t(p.name), rtl ? null : h("span", { class: "ob-ar" }, p.ar)),
      h("span", { class: "ob-tick" }))));
    return screen([kicker("Your alarms"), title("Which prayers should ring?"), lede("Start with the ones you miss most. You can change this any time."), list], cta);
  },

  sleeper() {
    return screen([
      kicker("Question 6"),
      title("How hard are you to wake up?"),
      single("sleeper", [
        { id: "deep", emoji: "🪨", label: "Very hard, I sleep through anything", sub: "Strict: rings until you scan your mat" },
        { id: "normal", emoji: "😪", label: "Normal, but I snooze", sub: "Strict, with a gentle start" },
        { id: "light", emoji: "🍃", label: "Easy, I just need a reminder", sub: "Moderate: stops after 10 minutes" },
      ], {
        after: (o) => {
          state.profile.alarmStrictness = o.id === "light" ? "moderate" : "strict";
          state.profile.commitmentLevel = o.id === "deep" ? "extremelyCommitted" : o.id === "normal" ? "committed" : "startingJourney";
          save();
          next();
        },
      }),
    ]);
  },

  goals() {
    const { list, cta } = multiGoals();
    return screen([kicker("Question 7"), title("What do you want salah to change for you?"), lede("Choose up to 3."), list], cta);
  },

  ramadanGoal() {
    return screen([
      h("p", { class: "ob-chip", style: "margin-bottom:12px" }, "🌙 ", t("Ramadan starts in about %d days", daysToRamadan())),
      title("Where do you want to be when Ramadan begins?"),
      single("ramadanGoal", [
        { id: "allFive", emoji: "🕌", label: "Praying all five, every day" },
        { id: "fajr", emoji: "☀️", label: "Never missing Fajr" },
        { id: "onTime", emoji: "⏰", label: "Praying on time, not catching up" },
        { id: "tahajjud", emoji: "🌌", label: "Adding Tahajjud before Fajr" },
      ]),
    ]);
  },

  // 15. Projection to Ramadan (motion: the line draws itself).
  projection() {
    const start = Math.max(0, Math.min(5, Number(state.a.yesterday ?? 2)));
    const days = daysToRamadan();
    const y = (v) => 150 - v * 26;
    const pts = [[20, y(start)], [110, y(Math.min(5, start + 1.6))], [200, y(Math.min(5, start + 2.6))], [300, y(5)]];
    const path = `M${pts[0][0]},${pts[0][1]} C70,${pts[0][1]} 80,${pts[1][1]} ${pts[1][0]},${pts[1][1]} S170,${pts[2][1]} ${pts[2][0]},${pts[2][1]} S270,${pts[3][1]} ${pts[3][0]},${pts[3][1]}`;
    const goal = { allFive: "all five prayers", fajr: "Fajr every day", onTime: "every prayer on time", tahajjud: "Tahajjud and Fajr" }[state.a.ramadanGoal] || "all five prayers";
    const chart = h("div", { class: "ob-card ob-chart", html: `
      <svg viewBox="0 0 320 180" role="img" aria-label="${t("Prayers per day rising from %d today to 5 by Ramadan", start)}">
        <defs><linearGradient id="ob-area" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#1a9e3f" stop-opacity=".25"/><stop offset="1" stop-color="#1a9e3f" stop-opacity="0"/></linearGradient></defs>
        <line class="grid" x1="20" x2="300" y1="${y(5)}" y2="${y(5)}"/><line class="grid" x1="20" x2="300" y1="${y(0)}" y2="${y(0)}"/>
        <path class="area" d="${path} L300,${y(0)} L20,${y(0)} Z"/>
        <path class="line" d="${path}"/>
        <g class="pin" style="animation-delay:.3s"><circle cx="20" cy="${y(start)}" r="7" fill="#fff" stroke="#c9a028" stroke-width="3"/></g>
        <g class="pin" style="animation-delay:1.9s"><circle cx="300" cy="${y(5)}" r="9" fill="#1a9e3f"/><text x="300" y="${y(5) + 4}" text-anchor="middle" fill="#fff" font-size="10" font-weight="800">5</text></g>
        <text class="lbl" x="20" y="174">${t("Today")}</text><text class="lbl" x="150" y="174" text-anchor="middle">${t("Day 30")}</text><text class="lbl" x="300" y="174" text-anchor="end">${t("Ramadan")}</text>
      </svg>` });
    return screen([
      kicker("Your path"),
      title(`${t("%d days is enough to reach", days)} ${t(goal)}.`),
      lede("Most of the change happens in the first 30 days, once Fajr stops being a fight. This is the curve we'll aim for together."),
      chart,
    ], primary("continue", next));
  },

  // 16. Proof: the App Store rating and the live challenge count.
  proof() {
    const count = h("b", {}, joined ? joined.toLocaleString() : "…");
    if (joined == null) {
      fetch("/ramadan-2027/stats.json").then((r) => r.json()).then((d) => { if (d?.joined) { joined = d.joined; count.textContent = joined.toLocaleString(); } }).catch(() => {});
    }
    return screen([
      kicker("Built for the Ummah"),
      title("You're in good company."),
      h("div", { class: "ob-card", style: "display:grid;gap:14px;margin-bottom:14px" },
        proofRow("⭐", h("b", {}, t("Rated 4.8 on the App Store")), t("From people who wanted to stop missing Fajr")),
        proofRow("🕋", h("div", {}, count, " ", t("people joined the Ramadan 2027 challenge")), t("Logging their prayers for 90 days")),
        proofRow("🌍", h("b", {}, t("In 5 languages")), "English · العربية · Türkçe · Bahasa · اردو")),
      h("ul", { class: "ob-list" },
        ["Exact prayer times for your city", "Adhan alarms that wake you up", "SalahLock for distracting apps", "Streaks, Qibla, Quran and duas"].map((b) => h("li", {}, svg(icons.check), t(b)))),
    ], primary("continue", next));
  },

  // 17. Commitment (motion: press and hold until the ring fills).
  commit() {
    const btn = h("button", { class: `ob-hold${state.a.committed ? " done" : ""}`, type: "button", "aria-label": t("Press and hold to commit") });
    btn.innerHTML = `<svg viewBox="0 0 168 168" aria-hidden="true"><circle class="bg" cx="84" cy="84" r="80"/><circle class="fg" cx="84" cy="84" r="80"/></svg>`;
    const inner = h("div", { class: "in" }, h("span", {}, state.a.committed ? "✓" : "🤲"), h("span", {}, t(state.a.committed ? "Committed" : "Hold")));
    btn.append(inner);
    const fg = btn.querySelector(".fg");
    const cta = primary("continue", next, { disabled: !state.a.committed });
    let raf = 0;
    let startAt = 0;
    const HOLD = 1600;
    const frame = () => {
      const p = Math.min(1, (performance.now() - startAt) / HOLD);
      fg.style.strokeDashoffset = String(502 * (1 - p));
      if (p >= 1) {
        state.a.committed = true;
        save();
        btn.classList.add("done");
        inner.replaceChildren(h("span", {}, "✓"), h("span", {}, t("Committed")));
        navigator.vibrate?.(40);
        capture("web_onboarding_committed", {});
        cta.disabled = false;
        later(next, 700);
        return;
      }
      raf = requestAnimationFrame(frame);
    };
    const start = (e) => { e.preventDefault(); if (state.a.committed) return; startAt = performance.now(); cancelAnimationFrame(raf); raf = requestAnimationFrame(frame); navigator.vibrate?.(10); };
    const stop = () => { if (state.a.committed) return; cancelAnimationFrame(raf); fg.style.transition = "stroke-dashoffset .3s"; fg.style.strokeDashoffset = "502"; later(() => { fg.style.transition = ""; }, 320); };
    btn.addEventListener("pointerdown", start);
    btn.addEventListener("pointerup", stop);
    btn.addEventListener("pointerleave", stop);
    btn.addEventListener("pointercancel", stop);
    btn.addEventListener("contextmenu", (e) => e.preventDefault());
    btn.addEventListener("keydown", (e) => { if (e.key === " " || e.key === "Enter") start(e); });
    btn.addEventListener("keyup", stop);
    return screen([
      kicker("Your intention"),
      title("Make the intention."),
      h("p", { class: "ob-card ob-center", style: "font-weight:700;font-size:17px" }, t("“Starting tomorrow, I will get up for Fajr and answer every call to prayer, in sha Allah.”")),
      btn,
      h("p", { class: "ob-small ob-center" }, t("Press and hold the circle")),
    ], cta);
  },

  // 18. Building the plan (motion: ring counts to 100).
  building() {
    const ticks = ["Finding prayer times for your city", "Setting your alarm strength", "Choosing the apps to pause", "Preparing your first 30 days"]
      .map((s) => h("li", {}, "✅", h("span", {}, t(s))));
    const ring = h("div", { class: "ob-ring", html: `<svg width="120" height="120" viewBox="0 0 120 120"><circle class="bg" cx="60" cy="60" r="52"/><circle class="fg" cx="60" cy="60" r="52"/></svg><b>0%</b>` });
    const el = h("section", { class: "ob-screen" }, h("div", { class: "ob-loader" }, ring, h("h2", { class: "ob-h1", style: "font-size:24px" }, t("Building your prayer plan…")), h("ul", { class: "ob-ticks" }, ticks)));
    const fg = ring.querySelector(".fg");
    const num = ring.querySelector("b");
    const total = 3200;
    const t0 = performance.now();
    const step = () => {
      const p = Math.min(1, (performance.now() - t0) / total);
      fg.style.strokeDashoffset = String(327 * (1 - p));
      num.textContent = `${Math.round(p * 100)}%`;
      ticks.forEach((li, i) => li.classList.toggle("on", p > (i + 0.5) / ticks.length));
      if (p < 1) later(step, 40);
      else later(() => { if (state.screen === "building") go("plan", { push: false }); }, 450);
    };
    later(step, 40);
    return el;
  },

  // 19. The plan, personalised.
  plan() {
    const first = firstAlarm(state.profile.selectedAlarmPrayers);
    const goal = GOALS.find((g) => g.id === state.profile.goals[0]);
    const strict = state.profile.alarmStrictness === "strict";
    const apps = APPS.filter((a) => state.a.distractions.includes(a.id)).map((a) => a.name);
    const row = (icon, k, v, d) => h("div", { class: "r" }, h("div", { class: "ic" }, svg(icon)), h("div", {}, h("div", { class: "k" }, k), h("div", { class: "v" }, v), d ? h("div", { class: "d" }, d) : null));
    return screen([
      h("p", { class: "ob-chip", style: "margin-bottom:12px" }, "✓ ", t("YOUR PLAN IS READY")),
      title("Your prayer plan"),
      h("div", { class: "ob-card ob-plan" },
        first ? row(icons.alarm, t("Your first alarm"), t("%@ at %@", t(first.name), first.time), [config.geo?.city, t("Exact time for your location")].filter(Boolean).join(" · ")) : null,
        row(icons.bell, t("Alarms"), t("%d prayers", state.profile.selectedAlarmPrayers.length), state.profile.selectedAlarmPrayers.map((id) => t(PRAYERS.find((p) => p.id === id).name)).join(" · ")),
        row(icons.shield, t("Alarm strength"), t(strict ? "Strict" : "Moderate"), t(strict ? "Rings until you scan your prayer mat" : "Stops after 10 minutes")),
        apps.length ? row(icons.lock, t("SalahLock"), t("%d apps paused at prayer time", apps.length), apps.join(" · ")) : null,
        row(icons.target, t("Goal"), goal ? t(goal.label) : t("build a consistent prayer habit"), t("%d days to Ramadan", daysToRamadan()))),
    ], primary("continue", next));
  },

  // 20. The free Ramadan challenge: open to everyone; Premium members are entered automatically.
  seat() {
    return screen([
      h("div", { class: "ob-ticket", style: "margin:8px 0 18px" },
        h("div", { class: "kaaba", "aria-hidden": "true" }),
        h("div", { class: "k" }, t("Ramadan 2027 challenge")),
        h("div", { class: "big" }, t("Free Makkah Trip draw")),
        h("div", { class: "seat" }, "🎟️ ", t("Free to join · included with Premium"))),
      title("You're invited to the free Ramadan challenge."),
      lede("The challenge is free for everyone. With Premium you're joined automatically: log your five prayers in the app for 30, 60 or 90 days to earn entries in the draw for Umrah for two, and invite friends for more."),
      h("p", { class: "ob-small" }, t("No purchase necessary to join or win; buying Premium does not improve your chances. Random draw on 10 Feb 2027."), " ",
        h("a", { href: "/ramadan-2027/rules/", target: "_blank", rel: "noopener" }, t("Rules"))),
    ], primary("Save my plan", next));
  },

  account() {
    let mode = device.android && device.inApp ? "inapp" : "choose";
    const error = h("p", { class: "ob-error", hidden: true, role: "alert" });
    const showError = (msg) => { error.hidden = !msg; error.textContent = msg || ""; };
    const body = h("div");
    const busy = (btn, on) => {
      btn.disabled = on;
      btn.dataset.label ||= btn.textContent;
      btn.replaceChildren(on ? h("span", { class: "ob-spinner" }) : "", on ? t("Signing you in...") : btn.dataset.label);
    };
    const google = h("button", { class: "ob-btn ob-google", type: "button" }, svg(icons.google), t("Continue with Google"));
    google.addEventListener("click", async () => {
      showError(null);
      busy(google, true);
      capture("web_signin_started", { method: "google", flow: "start" });
      try {
        const u = await auth.google();
        if (u) await signedIn(u, "google");
      } catch (err) {
        capture("web_signin_failed", { method: "google", code: err?.code || "unknown", flow: "start" });
        showError(authErrorMessage(err, t));
      } finally {
        busy(google, false);
      }
    });
    const emailForm = () => {
      const email = h("input", { id: "ob-email", type: "email", autocomplete: "email", inputmode: "email", required: true });
      const password = h("input", { id: "ob-password", type: "password", autocomplete: "new-password", minlength: 6, required: true });
      const submit = h("button", { class: "ob-btn ob-btn-primary", type: "submit" }, t("continue"));
      const form = h("form", { novalidate: true },
        h("div", { class: "ob-field" }, h("label", { for: "ob-email" }, t("Email")), email),
        h("div", { class: "ob-field" }, h("label", { for: "ob-password" }, t("Password")), password),
        submit);
      form.addEventListener("submit", async (e) => {
        e.preventDefault();
        showError(null);
        if (!/^\S+@\S+\.\S+$/.test(email.value.trim())) return showError(t("Please enter a valid email address."));
        if (password.value.length < 6) return showError(t("Use at least 6 characters for your password."));
        busy(submit, true);
        capture("web_signin_started", { method: "email", flow: "start" });
        try {
          const u = await auth.email(email.value.trim(), password.value, "");
          await signedIn(u, "email");
        } catch (err) {
          capture("web_signin_failed", { method: "email", code: err?.code || "unknown", flow: "start" });
          showError(authErrorMessage(err, t));
        } finally {
          busy(submit, false);
        }
      });
      return form;
    };
    const draw = () => {
      if (!auth) {
        body.replaceChildren(h("p", { class: "ob-notice" }, t("Sign-in is loading. If it doesn't appear, refresh the page.")));
      } else if (mode === "inapp") {
        const carried = btoa(unescape(encodeURIComponent(JSON.stringify({ screen: "account", a: state.a, profile: state.profile, plan: state.plan }))));
        const target = new URL(`/start/?resume=account&s=${encodeURIComponent(carried)}${ref ? `&ref=${encodeURIComponent(ref)}` : ""}${aff ? `&via=${encodeURIComponent(aff)}` : ""}`, location.href).href;
        body.replaceChildren(
          h("p", { class: "ob-notice" }, t("Google sign-in doesn't work inside this app's browser. Open this page in Chrome, or use email.")),
          h("a", { class: "ob-btn ob-btn-primary", href: chromeIntent(target), style: "margin-top:12px", onclick: () => capture("web_open_in_chrome_tapped", { from: device.inApp, flow: "start" }) }, t("Open in Chrome")),
          h("div", { class: "ob-divider" }, t("or")),
          emailForm());
      } else if (mode === "email") {
        body.replaceChildren(emailForm(), h("button", { class: "ob-link", type: "button", onclick: () => { mode = "choose"; draw(); } }, t("Continue with Google")));
      } else {
        body.replaceChildren(
          google,
          h("button", { class: "ob-btn ob-btn-ghost", type: "button", style: "margin-top:10px", onclick: () => { mode = "email"; draw(); capture("web_email_option_tapped", { flow: "start" }); } }, t("Continue with Email")));
      }
    };
    draw();
    return screen([
      kicker("Last step"),
      title("Save your plan"),
      lede("Create your account so your plan, alarms and challenge are waiting in the app. Use the same account to sign in on your phone."),
      body,
      error,
      h("p", { class: "ob-small", style: "margin-top:14px" }, t("We'll never post anything or share your email.")),
    ]);
  },

  paywall() {
    const plans = config.plans?.length ? config.plans : [];
    const first = firstAlarm(state.profile.selectedAlarmPrayers);
    const error = h("p", { class: "ob-error", hidden: true, role: "alert" });
    const cta = primary("Start my plan", () => startCheckout(cta, error), { disabled: !plans.length, id: "checkout" });
    const weekly = plans.find((p) => p.plan === "weekly");
    const planCard = (p) => {
      const isYearly = p.plan === "yearly";
      const price = money(p.amount, p.currency);
      const deal = config.discount?.plan === p.plan ? config.discount : null;
      const savePct = isYearly && weekly && weekly.currency === p.currency ? Math.round((1 - p.amount / (weekly.amount * 52)) * 100) : 0;
      return h("button", {
        class: "ob-planbtn", type: "button", role: "radio", "aria-checked": String(p.plan === state.plan),
        onclick: () => {
          state.plan = p.plan;
          save();
          capture("web_plan_selected", { plan: p.plan, price: p.amount, currency: p.currency, flow: "start" });
          render();
        },
      },
      isYearly ? h("span", { class: "flag" }, savePct > 0 ? t("SAVE %d%", savePct) : t("BEST VALUE")) : null,
      h("span", { class: "radio" }),
      h("span", {},
        h("span", { class: "name" }, t(isYearly ? "Yearly" : "Weekly")),
        h("span", { class: "meta" }, deal ? t("First year %@, then %@ yearly", money(deal.amount, deal.currency), price) : t(isYearly ? "Billed %@ annually" : "Billed %@ weekly", price))),
      h("span", { class: "price" }, t("%@/week", money(isYearly ? p.weeklyEquivalent : p.amount, p.currency))));
    };
    const goalLine = { allFive: "Pray all five, every day, by Ramadan", fajr: "Never miss Fajr again, starting tomorrow", onTime: "Pray every prayer on time by Ramadan", tahajjud: "Wake for Tahajjud and Fajr by Ramadan" }[state.a.ramadanGoal] || "Never miss Fajr again, starting tomorrow";
    return screen([
      h("div", { style: "position:relative" },
        !state.exitsSeen.includes("offer") && config.offer ? h("button", { class: "ob-close", type: "button", "aria-label": t("Close"), onclick: closePaywall }, "×") : null,
        first ? h("p", { class: "ob-chip", style: "margin-bottom:12px" }, "⏰ ", t("First alarm: %@ at %@", t(first.name), first.time)) : null),
      lapsed ? h("p", { class: "ob-notice", style: "margin-bottom:12px" }, t("Your plan has ended. Renew to turn your prayer alarms back on.")) : null,
      config.discount ? h("p", { class: "ob-notice", style: "margin-bottom:12px" }, t("Your %d% discount is applied to the yearly plan.", config.discount.percentOff)) : null,
      title(goalLine),
      h("ul", { class: "ob-list", style: "margin:4px 0 6px" },
        ["Adhan alarms that only stop at your prayer mat", "SalahLock pauses your distracting apps", "Exact prayer times, streaks, Qibla and Quran", "🕋 Joined to the free Makkah Trip challenge automatically"].map((b) => h("li", {}, svg(icons.check), t(b)))),
      plans.length ? h("div", { class: "ob-plans", role: "radiogroup" }, plans.map(planCard)) : h("p", { class: "ob-notice" }, t("loading deals...")),
    ], [
      error,
      cta,
      h("div", { class: "ob-trust" }, h("span", {}, "✓ ", t("Cancel anytime")), h("span", {}, "🔒 ", t("Secure checkout"))),
      h("div", { class: "ob-links" },
        h("a", { href: "/start/paid/" }, t("Already paid?")),
        h("a", { href: "https://ramadan-pro.lovable.app/privacy", target: "_blank", rel: "noopener" }, t("Privacy")),
        h("a", { href: "https://ramadan-pro.lovable.app/terms", target: "_blank", rel: "noopener" }, t("Terms"))),
    ]);
  },

  offer() {
    const o = config.offer;
    const error = h("p", { class: "ob-error", hidden: true, role: "alert" });
    const cta = primary(o?.percentOff ? t("Claim my %d% off", o.percentOff) : t("Claim my offer"), () => startCheckout(cta, error, "weeklyOffer"), { disabled: !o, id: "checkout-offer" });
    return screen([
      h("p", { class: "ob-chip", style: "margin-bottom:12px" }, t("ONE-TIME OFFER")),
      title("Wait. Here's a better price, just for you."),
      lede("We don't want price to be the thing between you and Fajr."),
      o ? h("div", { class: "ob-offer" },
        o.percentOff ? h("div", { class: "off" }, t("%d% OFF", o.percentOff)) : null,
        h("div", { class: "p" }, o.regularAmount ? h("s", {}, money(o.regularAmount, o.currency)) : null, " ", t("%@/week", money(o.amount, o.currency))),
        h("div", { class: "ob-small" }, t("Billed %@ weekly. Cancel anytime.", money(o.amount, o.currency)))) : h("p", { class: "ob-notice" }, t("loading deals...")),
      h("ul", { class: "ob-list", style: "margin-top:16px" },
        ["Adhan alarms that only stop at your prayer mat", "SalahLock pauses your distracting apps", "🕋 Joined to the free Makkah Trip challenge automatically"].map((b) => h("li", {}, svg(icons.check), t(b)))),
    ], [
      error,
      cta,
      h("button", { class: "ob-link", type: "button", onclick: () => { capture("web_exit_offer_declined", { flow: "start" }); go("paywall"); } }, t("No thanks, show the plans")),
    ]);
  },
};

function proofRow(emoji, main, sub) {
  return h("div", { class: "ob-row" }, h("span", { style: "font-size:30px" }, emoji), h("div", {}, main, h("div", { class: "ob-small" }, sub)));
}

function multiGoals() {
  const selected = new Set(state.profile.goals);
  const cta = primary("continue", () => {
    capture("web_goals_selected", { goals: state.profile.goals.join(","), flow: "start" });
    next();
  }, { disabled: selected.size === 0 });
  const list = h("div", { class: "ob-options" }, GOALS.map((g) =>
    h("button", {
      class: "ob-opt", type: "button", "aria-pressed": String(selected.has(g.id)), "data-id": g.id,
      onclick: () => {
        if (selected.has(g.id)) selected.delete(g.id);
        else if (selected.size < 3) selected.add(g.id);
        state.profile.goals = GOALS.map((x) => x.id).filter((id) => selected.has(id));
        save();
        for (const b of list.children) b.setAttribute("aria-pressed", String(selected.has(b.dataset.id)));
        cta.disabled = selected.size === 0;
      },
    }, h("span", { class: "ob-emoji" }, g.emoji), h("span", { class: "ob-label" }, t(g.label)), h("span", { class: "ob-tick" }))));
  return { list, cta };
}

// ---- plan helpers ----------------------------------------------------------------

function firstAlarm(ids) {
  const s = config.schedule;
  if (!s?.times) return null;
  const now = Date.now();
  const tz = config.geo?.timezone;
  const order = PRAYERS.filter((p) => ids.includes(p.id));
  for (const p of order) if (Date.parse(s.times[p.id]) > now) return { name: p.name, time: timeIn(s.times[p.id], tz) };
  const p = order[0];
  return p && s.tomorrow ? { name: p.name, time: timeIn(s.tomorrow[p.id], tz) } : null;
}

// ---- auth + checkout --------------------------------------------------------------

async function signedIn(u, method) {
  user = u;
  identify(u.uid, u.email);
  capture("web_signin_completed", { method, provider: u.provider, flow: "start" });
  setPersonProps({ email: u.email || undefined, web_funnel: "start", missed_fajr: state.a.missFajr, ramadan_goal: state.a.ramadanGoal, ...(aff && { affiliate: aff }) });
  const token = await u.token();
  api("/api/profile", { method: "POST", token, body: { profile: { ...state.profile, displayName: u.name || "", lastCompletedScreen: "screen17" } } })
    .catch((err) => console.warn("profile save failed", err));
  if (await alreadySubscribed(token)) return;
  go("paywall");
}

async function alreadySubscribed(token) {
  try {
    const { entitlement } = await api("/api/entitlement", { token });
    lapsed = entitlement?.provider === "dodo" && !entitlement.active;
    if (lapsed) capture("web_renewal_paywall", { status: entitlement.status, flow: "start" });
    if (entitlement?.active && entitlement.status !== "trial") {
      capture("web_returning_subscriber", { flow: "start" });
      location.href = "/start/paid/";
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
  btn.replaceChildren(h("span", { class: "ob-spinner" }), t("processing..."));
  capture("web_checkout_started", { plan: plan?.plan, price: plan?.amount, currency: plan?.currency, flow: "start" });
  affiliateBeacon("checkout_started", { app_user_id: user.uid, platform: "web", plan: plan?.plan });
  try {
    const token = await user.token();
    const res = await api("/api/checkout", {
      method: "POST",
      token,
      body: { plan: plan.plan, lang: currentLang(), ref, name: user.name || "", discount: config.discount?.code, flow: "start", affiliate: aff },
    });
    if (res.alreadyActive) {
      location.href = "/start/paid/";
      return;
    }
    store.set("sa_checkout", JSON.stringify({ sessionId: res.sessionId, plan: plan.plan, at: Date.now() }));
    location.href = res.checkoutUrl;
  } catch (err) {
    capture("web_checkout_failed", { status: err.status || 0, message: err.message, flow: "start" });
    error.textContent = err.status === 503
      ? t("Checkout is not available yet. Please try again soon.")
      : navigator.onLine === false ? t("No internet connection. Please try again.") : t("Something went wrong. Please try again.");
    error.hidden = false;
    btn.disabled = false;
    btn.replaceChildren(label);
  }
}

// Every tap on a button or link inside the flow, with the screen it happened on.
root.addEventListener("click", (e) => {
  const el = e.target.closest("button, a");
  if (!el || !root.contains(el)) return;
  capture("web_onboarding_tap", { screen: state.screen, label: (el.getAttribute("aria-label") || el.textContent || "").trim().slice(0, 60), kind: el.dataset.obCta || el.className.split(" ")[0] || el.tagName.toLowerCase() });
}, true);

// Leaving the page (closing the tab, going to an external link) closes the current screen.
addEventListener("pagehide", () => capture("web_onboarding_left", { screen: state.screen, duration_ms: Date.now() - shownAt }));

// ---- boot -------------------------------------------------------------------------

async function boot() {
  ref = captureRef();
  aff = affiliate();
  setLang(initialLang(), { persist: false });
  backBtn.innerHTML = icons.back;
  backBtn.addEventListener("click", back);
  restore();
  // Paint the first screen right away with fallback data; config fills in prices and times.
  root.hidden = false;
  render();

  config = await loadConfig();
  if (config.discount) state.plan = config.discount.plan;
  setLang(initialLang(config.lang), { persist: false });
  root.querySelector("[data-ob-lang]")?.replaceChildren(langSelect(() => render()));
  initAnalytics(config, { ref, page: "start_onboarding", funnel: "start", country: config.geo?.country, price_tier: config.tier, entry: location.pathname }, { sdk: true });
  if (!store.get("sa_start_started")) {
    store.set("sa_start_started", "1");
    capture("web_onboarding_started", { entry: location.pathname, ref, landing_screen: state.screen, flow: "start" });
  }

  try {
    auth = await initAuth(config.firebase);
    user = await auth.ready;
    if (user) identify(user.uid, user.email);
    if (user && state.screen === "account") {
      await signedIn(user, user.provider === "password" ? "email" : "google");
      return;
    }
  } catch (err) {
    console.warn("auth unavailable", err);
  }
  if ((state.screen === "paywall" || EXITS.includes(state.screen)) && !user) state.screen = "account";
  if (user && (state.screen === "paywall" || EXITS.includes(state.screen)) && (await alreadySubscribed(await user.token()))) return;
  history.replaceState({ screen: state.screen }, "");
  render();
}

boot();
