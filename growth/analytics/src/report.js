// Writes the daily brief (Markdown) and a one-page HTML dashboard from the
// same snapshot.
import { pct } from './funnel.js';
import { CHANNELS } from './channels.js';

const fmt = (n) => (n === null || n === undefined ? '–' : n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e4 ? `${Math.round(n / 1e3)}K` : n >= 1e3 ? `${(n / 1e3).toFixed(1)}K` : String(Math.round(n)));
const r1 = (n) => (n === null || n === undefined ? '–' : n.toFixed(1));
const short = (t, n = 70) => (t || '').replace(/\s+/g, ' ').replace(/\|/g, '/').slice(0, n);
const link = (it) => `[${it.platform} @${it.author || '?'}](${it.url})`;

export function markdown(s) {
  const L = [];
  L.push(`# Salah Alarm daily brief, ${s.date}`, '');
  L.push('## 1. Funnel: is the app turning installs into money?', '');
  if (!s.funnel) L.push('_No funnel data (PostHog key missing)._', '');
  else {
    const { alerts, steps, totals } = s.funnel;
    if (!alerts.length) L.push('No alerts. The funnel held up this week.', '');
    for (const a of alerts) L.push(`- ${a.level === 'red' ? '🔴' : '🟠'} ${a.text}`);
    L.push('', `Last 7 full days: ${totals.cur.installs} installs, ${totals.cur.paywall_viewed} saw the paywall, ${totals.cur.buy_tapped} tapped buy, ${totals.cur.purchased} purchased (PostHog).`, '');
    L.push('| Step | This week | Week before | People |', '|---|---|---|---|');
    for (const st of steps) L.push(`| ${st.label} | ${pct(st.now)} | ${pct(st.before)} | ${st.n} |`);
    L.push('');
  }
  if (s.android?.length) {
    const cur = s.android.find((r) => r.period === 'this') || {};
    const prev = s.android.find((r) => r.period === 'prev') || {};
    const rows = [['Bio page views', 'bio_views'], ['Tapped Android', 'tapped_android'], ['Tapped iPhone', 'tapped_ios'], ['Web onboarding started', 'onboarding_started'],
      ['Saw web paywall', 'paywall_viewed'], ['Exit offer shown', 'exit_offer_viewed'], ['Free trials started', 'trials'], ['Started checkout', 'checkout_started'],
      ['Paid (Dodo)', 'paid'], ['APK taps', 'apk_taps'], ['APK downloads', 'apk_downloads'], ['First app opens', 'app_first_open']];
    L.push('**Android web funnel (salahalarm.com/get), last 7 full days:**', '', '| Step | This week | Week before |', '|---|---|---|');
    for (const [label, k] of rows) L.push(`| ${label} | ${fmt(cur[k] ?? 0)} | ${fmt(prev[k] ?? 0)} |`);
    L.push('');
  } else if (s.android) L.push('**Android web funnel:** no events yet.', '');
  if (s.revenue) {
    const v = s.revenue;
    L.push(`**RevenueCat:** MRR $${fmt(v.mrr)}, revenue last 28 days $${fmt(v.revenue)}, active trials ${fmt(v.active_trials)}, active subscriptions ${fmt(v.active_subscriptions)}, new customers ${fmt(v.new_customers)}.`, '');
  }

  L.push('## 2. Channels, last 7 days', '');
  L.push('| Channel | Posts | Views | Shares+saves | Link clicks | Clicks /1K views | Installs (App Store) | Installs /1K views |', '|---|---|---|---|---|---|---|---|');
  for (const c of CHANNELS) {
    const r = s.channels[c];
    if (!r) continue;
    const empty = !r.posts && !r.views && !r.clicks && !r.installs;
    L.push(`| ${c}${empty ? ' (not started)' : ''} | ${r.posts} | ${fmt(r.views)} | ${fmt(r.passOn)} | ${r.clicks} | ${r1(r.clicksPer1k)} | ${r.installs || '–'} | ${r1(r.installsPer1k)} |`);
  }
  L.push('', '_SEO views are Google clicks to the site. App Store installs come from the campaign CSV in data/inbox/ and lag about a day._', '');

  L.push('## 3. Content library', '');
  const lib = s.library;
  L.push('_~ means views estimated from likes (Instagram hides plays). "Unverified" counts were read by an assistant and get re-checked by the scraper._', '');
  L.push(`${lib.total} posts in the library (${lib.external} from other accounts, ${lib.own} ours), ${lib.added} added today. Goal: 1,000 proven posts to clip from.`, '');
  L.push(`By platform: ${Object.entries(lib.byPlatform).map(([k, v]) => `${k} ${v}`).join(', ')}. By format: ${Object.entries(lib.byFormat).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k} ${v}`).join(', ')}.`, '');
  section(L, 'Clip next: best unclipped posts', s.clipQueue, (it) => `${link(it)} ${it.viewsEstimated ? '~' : ''}${fmt(it.views)} views${it.unverified ? ' (unverified)' : ''}, ${it.outlier ? `${r1(it.outlier)}× followers, ` : ''}${it.shareRate === null ? '' : `${pct(it.shareRate)} pass-on, `}${it.formats.join('/')}: "${short(it.text)}"`);
  section(L, 'Rising fastest since yesterday', s.rising, (it) => `${link(it)} +${fmt(it.growth)}/day, now ${fmt(it.views)}: "${short(it.text)}"`);
  section(L, 'App promos that worked (copy the structure)', s.promos, (it) => `${link(it)} ${fmt(it.views)} views${it.competitor ? `, ${it.competitor}` : ''}: "${short(it.text)}"`);

  if (s.ads) {
    L.push(`**Ads still running longest** (Meta Ad Library, captured ${s.ads.capturedOn || '?'}, ${s.ads.total} ads). Months of spend on one creative is a sign it works for them; copy the structure, not the ad.`, '');
    const ad = (a) => `[${a.advertiser}](${a.library_url}) ${a.days_running} days, ${a.media_type}${a.variations_same_creative ? `, ${a.variations_same_creative} copies` : ''}: "${short(a.hook || a.headline, 80)}"`;
    section(L, 'Muslim apps', s.ads.niche, ad);
    section(L, 'Other faith apps', s.ads.faith, ad);
    section(L, 'Outside the niche', s.ads.outside, ad);
  }

  L.push('## 4. Our own posts', '');
  if (!s.own.length) L.push('_No own posts yet (Zernio key missing, or nothing posted in the window)._', '');
  else {
    L.push('| Post | Account | Views | Pass-on | Profile visits | Link clicks (est.) | Score |', '|---|---|---|---|---|---|---|');
    for (const it of s.own) L.push(`| [${short(it.text, 40) || it.id}](${it.url}) | ${it.account || it.author || '?'} | ${fmt(it.views)} | ${pct(it.shareRate)} | ${fmt(it.metrics?.profileViews)} | ${it.conv ? r1(it.conv.clicks) : '–'} | ${it.score} |`);
    L.push('');
  }

  if (s.errors.length) {
    L.push('## Data gaps', '');
    for (const e of s.errors) L.push(`- ${e}`);
    L.push('');
  }
  return L.join('\n');
}

function section(L, title, items, line) {
  L.push(`**${title}**`, '');
  if (!items.length) L.push('_None yet._');
  items.forEach((it, i) => L.push(`${i + 1}. ${line(it)}`));
  L.push('');
}

// A self-contained page; open it locally or publish it.
export function html(s, md) {
  const esc = (t) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;');
  // Links are set aside first so emphasis never rewrites underscores inside a URL.
  const links = [];
  const body = esc(md)
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, text, href) => `\u0000${links.push(`<a href="${href}" target="_blank" rel="noopener">${text}</a>`) - 1}\u0000`)
    .replace(/^# (.*)$/gm, '<h1>$1</h1>').replace(/^## (.*)$/gm, '<h2>$1</h2>')
    .replace(/\*\*(.+?)\*\*/g, '<b>$1</b>').replace(/_(.+?)_/g, '<i>$1</i>')
    .replace(/\u0000(\d+)\u0000/g, (_, i) => links[i])
    .replace(/((?:^\|.*\|$\n?)+)/gm, (tbl) => {
      const rows = tbl.trim().split('\n').filter((r) => !/^\|[-| ]+\|$/.test(r));
      return '<table>' + rows.map((r, i) => `<tr>${r.slice(1, -1).split('|').map((c) => `<${i ? 'td' : 'th'}>${c.trim()}</${i ? 'td' : 'th'}>`).join('')}</tr>`).join('') + '</table>';
    })
    .replace(/^- (.*)$/gm, '<li>$1</li>').replace(/^\d+\. (.*)$/gm, '<li>$1</li>')
    .replace(/\n{2,}/g, '\n<p></p>\n');
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Salah Alarm daily</title><style>
:root{--bg:#fbfaf7;--fg:#1d1d1b;--mut:#6b6a66;--line:#e4e1da;--acc:#0f6b4f}
@media (prefers-color-scheme:dark){:root{--bg:#141413;--fg:#ecebe6;--mut:#a3a19a;--line:#33322f;--acc:#5fc9a2}}
body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;max-width:1100px;margin:0 auto;padding:16px}
h1{font-size:24px}h2{font-size:18px;margin-top:28px;border-top:1px solid var(--line);padding-top:16px}
table{border-collapse:collapse;width:100%;display:block;overflow-x:auto;font-size:13px}th,td{border-bottom:1px solid var(--line);padding:6px 8px;text-align:left;white-space:nowrap}
a{color:var(--acc)}li{margin:4px 0}i{color:var(--mut)}
</style></head><body>${body}</body></html>`;
}
