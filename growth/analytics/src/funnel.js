// Funnel health: compares the last 7 full days with the 7 before and raises
// plain-language alerts when onboarding, the paywall or the offer is losing
// people. Content is only worth scaling when this funnel holds up.

const STEPS = [
  ['installs', 'onboarding_completed', 'Onboarding completion', 0.6],
  ['installs', 'paywall_viewed', 'Reach the paywall', 0.55],
  ['paywall_viewed', 'buy_tapped', 'Tap buy on the paywall', 0.15],
  ['buy_tapped', 'purchased', 'Finish checkout after tapping buy', 0.35],
  ['installs', 'purchased', 'Install to paid', 0.02],
];

const sum = (rows, k) => rows.reduce((s, r) => s + Number(r[k] || 0), 0);
// Capped at 100%: people who installed last week can reach the paywall this week.
const rate = (a, b) => (b > 0 ? Math.min(1, a / b) : null);

// Windows are bounded by date, not row count: PostHog returns no row for a day
// with no events. Today is partial, so it is left out.
const daysBefore = (day, n) => new Date(Date.parse(day + 'T00:00:00Z') - n * 864e5).toISOString().slice(0, 10);
export function windows(daily, today) {
  const [d1, d7, d14] = [1, 7, 14].map((n) => daysBefore(today, n));
  const cur = daily.filter((r) => r.day >= d7 && r.day < today);
  const prev = daily.filter((r) => r.day >= d14 && r.day < d7);
  return { cur, prev, yesterday: daily.find((r) => r.day === d1) || null };
}

export function analyse(daily, screens = [], today) {
  const { cur, prev, yesterday } = windows(daily, today);
  const steps = STEPS.map(([from, to, label, floor]) => {
    const now = rate(sum(cur, to), sum(cur, from));
    const before = rate(sum(prev, to), sum(prev, from));
    return { from, to, label, floor, now, before, n: sum(cur, from), change: now !== null && before ? now / before - 1 : null };
  });

  const alerts = [];
  const noPurchases = sum(cur, 'installs') >= 30 && sum(cur, 'purchased') === 0;
  for (const s of steps) {
    if (s.now === null || s.n < 15) continue; // too few people to judge
    if (noPurchases && s.to === 'purchased') continue; // covered by the alert below
    if (s.now < s.floor) alerts.push({ level: 'red', text: `${s.label} is ${pct(s.now)} (floor ${pct(s.floor)}, ${s.n} people).` });
    else if (s.change !== null && s.change < -0.25) alerts.push({ level: 'amber', text: `${s.label} fell ${pct(-s.change)} week on week, to ${pct(s.now)}.` });
  }

  const taps = sum(cur, 'buy_tapped');
  const cancels = sum(cur, 'sheet_cancelled');
  if (taps >= 10 && cancels / taps > 0.6)
    alerts.push({
      level: 'red',
      text: `${pct(cancels / taps)} of people who tapped buy then cancelled on Apple's payment sheet (${cancels} of ${taps}). The price or "charged today" on the sheet is a surprise: show the real price and billing date on the paywall, or add a free trial.`,
    });
  const errors = sum(cur, 'purchase_errors');
  if (errors >= 3) alerts.push({ level: 'red', text: `${errors} people hit a real purchase error (not a cancel) this week. Check the build and StoreKit products.` });
  if (noPurchases)
    alerts.push({ level: 'red', text: `No purchase recorded in PostHog from ${sum(cur, 'installs')} installs this week. Check RevenueCat: either nobody is paying or purchase_completed isn't firing in this build.` });
  const offerShown = sum(cur, 'final_offer_shown');
  if (sum(cur, 'paywall_viewed') >= 30 && offerShown === 0)
    alerts.push({ level: 'amber', text: 'The final discount offer was never shown this week. If it should be live, the yearlydiscounted product may be missing from the current offering.' });

  const leak = worstScreen(screens);
  if (leak && leak.loss >= 0.08)
    alerts.push({ level: leak.loss >= 0.15 ? 'red' : 'amber', text: `Onboarding screen "${leak.screen}" loses ${pct(leak.loss)} of people who reach the screen before it (${leak.from} → ${leak.to} this week).` });

  return { steps, alerts, yesterday, totals: { cur: totals(cur), prev: totals(prev) }, leak };
}

function totals(rows) {
  const keys = ['installs', 'onboarding_completed', 'paywall_viewed', 'buy_tapped', 'sheet_cancelled', 'purchase_errors', 'purchased', 'link_clicks'];
  return Object.fromEntries(keys.map((k) => [k, sum(rows, k)]));
}

// The screen with the biggest share of people lost relative to the earlier
// screens. Some screens are also reached by people resuming onboarding, which
// inflates them, so each screen is compared with the smallest count before it.
export function worstScreen(screens) {
  // Screens seen by fewer than 10 people (a build still rolling out) are left out.
  const s = [...screens].filter((r) => r.idx != null && Number(r.this_week) >= 10).sort((a, b) => a.idx - b.idx);
  let worst = null;
  let from = s.length ? Number(s[0].this_week) : 0;
  for (let i = 1; i < s.length; i++) {
    const to = Number(s[i].this_week);
    const loss = 1 - to / from;
    if (!worst || loss > worst.loss) worst = { screen: s[i].screen, from, to, loss };
    from = Math.min(from, to);
  }
  return worst;
}

export const pct = (x) => (x === null || x === undefined ? 'n/a' : `${(x * 100).toFixed(x < 0.1 ? 1 : 0)}%`);
