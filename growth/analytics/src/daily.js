#!/usr/bin/env node
// The daily run. Every source is optional: a missing key skips that source and
// is listed under "Data gaps" in the brief, so the run never fails halfway.
//
//   node src/daily.js                  normal run, reads keys from the environment
//   node src/daily.js --posthog-file f use a saved PostHog snapshot instead of the API
//   node src/daily.js --no-discovery   skip Apify (saves credits)
import { readFileSync, writeFileSync, mkdirSync, existsSync, appendFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as apify from './collect/apify.js';
import * as zernio from './collect/zernio.js';
import * as posthog from './collect/posthog.js';
import * as gsc from './collect/gsc.js';
import { revenuecat, ascCampaigns } from './collect/revenue.js';
import { readInbox } from './collect/inbox.js';
import { load, save, merge, ranked, toCsv, attachConversions } from './library.js';
import { analyse } from './funnel.js';
import { scoreboard, CHANNELS } from './channels.js';
import { markdown, html } from './report.js';
import { load as loadAds, topAds } from './ads.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const P = (...p) => join(ROOT, ...p);
const args = process.argv.slice(2);
const flag = (f) => args.includes(f);
const opt = (f) => (args.includes(f) ? args[args.indexOf(f) + 1] : null);
const env = process.env;

const day = (offset = 0) => new Date(Date.now() + offset * 864e5).toISOString().slice(0, 10);
const today = opt('--date') || day();
const weekAgo = day(-7);

const cfg = JSON.parse(readFileSync(P('config/sources.json'), 'utf8'));
const accounts = JSON.parse(readFileSync(P('config/accounts.json'), 'utf8'));
const errors = [];
const gap = (what, why) => errors.push(`${what}: ${why}`);

mkdirSync(P('data/inbox'), { recursive: true });
mkdirSync(P('reports'), { recursive: true });
const lib = load(P('data/library.json'));
const counts = { added: 0 };
const tally = (c) => { counts.added += c.added; };

// 1. Hand-found posts (ChatGPT, Muse, a VA). Read first so the scraper can verify them.
const inbox = readInbox(P('data/inbox/manual.csv'));
tally(merge(lib, inbox, cfg, today));

// 2. Discovery through Apify.
if (flag('--no-discovery')) gap('Discovery', 'skipped (--no-discovery)');
else if (!env.APIFY_TOKEN) gap('Discovery (TikTok, Instagram, X)', 'APIFY_TOKEN not set');
else {
  const verifyUrls = Object.values(lib).filter((it) => it.unverified).map((it) => it.url).slice(0, 100);
  const r = await apify.collect(cfg, env.APIFY_TOKEN, { verifyUrls });
  errors.push(...r.errors);
  tally(merge(lib, r.items, cfg, today));
}

// 3. Our own posts through Zernio.
let zDaily = null;
if (!env.ZERNIO_API_KEY) gap('Own posts (Zernio)', 'ZERNIO_API_KEY not set');
else {
  const r = await zernio.collect(env.ZERNIO_API_KEY, accounts, { fromDate: day(-30), toDate: today });
  errors.push(...r.errors);
  zDaily = r.daily;
  tally(merge(lib, r.items, cfg, today));
}

// 4. Funnel and link clicks through PostHog.
let ph = null;
if (opt('--posthog-file')) ph = JSON.parse(readFileSync(opt('--posthog-file'), 'utf8'));
else if (!env.POSTHOG_PERSONAL_API_KEY) gap('Funnel (PostHog)', 'POSTHOG_PERSONAL_API_KEY not set');
else ph = await posthog.collect(env.POSTHOG_PERSONAL_API_KEY);
if (ph?.errors) errors.push(...ph.errors);
const funnel = ph?.daily ? analyse(ph.daily, ph.screens || [], today) : null;

// 5. SEO through Search Console (data lags ~2 days).
let gscRows = [];
if (!env.GSC_SERVICE_ACCOUNT_JSON) gap('SEO (Search Console)', 'GSC_SERVICE_ACCOUNT_JSON not set');
else {
  try { gscRows = (await gsc.collect(env.GSC_SERVICE_ACCOUNT_JSON, { startDate: day(-9), endDate: day(-2) })).rows; }
  catch (e) { errors.push(e.message); }
}

// 6. Money and App Store installs.
let revenue = null;
if (!env.REVENUECAT_API_KEY || !env.REVENUECAT_PROJECT_ID) gap('Revenue (RevenueCat)', 'REVENUECAT_API_KEY / REVENUECAT_PROJECT_ID not set');
else { try { revenue = await revenuecat(env.REVENUECAT_API_KEY, env.REVENUECAT_PROJECT_ID); } catch (e) { errors.push(e.message); } }
const asc = ascCampaigns(P('data/inbox/asc-campaigns.csv')).filter((r) => r.date >= weekAgo);
if (!asc.length) gap('App Store installs per link', 'no rows in data/inbox/asc-campaigns.csv for the last 7 days');

// 7. Join clicks and installs onto our own posts, then build the scoreboard.
const links = (ph?.links || []).map((l) => ({ account: l.account, clicks: Number(l.clicks) }));
const perAccount = {};
for (const l of links) (perAccount[l.account] ||= { clicks: 0, installs: null }).clicks += l.clicks;
for (const a of asc) (perAccount[a.account] ||= { clicks: 0, installs: 0 }).installs = (perAccount[a.account].installs || 0) + a.installs;
attachConversions(lib, perAccount);

const ownWeek = ranked(lib, { own: true }).filter((it) => (it.postedAt || '') >= weekAgo);
const channels = scoreboard({ ownPosts: ownWeek, links, gsc: gscRows, asc });

const all = Object.values(lib);
const external = all.filter((it) => !it.own);
const countBy = (xs, f) => xs.reduce((m, x) => { for (const k of [].concat(f(x))) m[k] = (m[k] || 0) + 1; return m; }, {});
const snapshot = {
  date: today,
  funnel,
  revenue,
  channels,
  zernioDaily: zDaily?.platformBreakdown || null,
  library: {
    total: all.length, own: all.length - external.length, external: external.length, added: counts.added,
    byPlatform: countBy(external, (x) => x.platform), byFormat: countBy(external, (x) => x.formats || []),
  },
  clipQueue: ranked(lib, { own: false }).filter((it) => it.status === 'new' || it.status === 'unverified').slice(0, 20),
  rising: external.filter((it) => it.growth > 0).sort((a, b) => b.growth - a.growth).slice(0, 10),
  promos: ranked(lib, { own: false }).filter((it) => it.promo).slice(0, 10),
  own: ranked(lib, { own: true }).slice(0, 15),
  ads: (() => {
    const a = loadAds(P('data/ads-library.json'));
    return a && { capturedOn: a.capturedOn, total: a.ads.length, niche: topAds(a.ads, { group: 'niche', limit: 8 }), outside: topAds(a.ads, { group: 'outside_niche', limit: 8 }), faith: topAds(a.ads, { group: 'faith_adjacent', limit: 6 }) };
  })(),
  errors,
};

save(P('data/library.json'), lib);
writeFileSync(P('data/library.csv'), toCsv(ranked(lib)));
writeFileSync(P('data/latest.json'), JSON.stringify(snapshot, null, 1));
const md = markdown(snapshot);
writeFileSync(P(`reports/${today}.md`), md);
writeFileSync(P('reports/latest.md'), md);
writeFileSync(P('reports/dashboard.html'), html(snapshot, md));

// One line per channel per day, for trends over weeks.
const hist = P('data/channels-history.csv');
if (!existsSync(hist)) writeFileSync(hist, 'date,channel,posts,views,pass_on,clicks,installs,proceeds\n');
for (const c of CHANNELS) {
  const r = channels[c];
  appendFileSync(hist, `${today},${c},${r.posts},${r.views},${r.passOn},${r.clicks},${r.installs},${r.proceeds}\n`);
}

console.log(`library ${all.length} (+${counts.added}), alerts ${funnel?.alerts.length ?? 'n/a'}, gaps ${errors.length}`);
console.log(`brief: reports/${today}.md`);
