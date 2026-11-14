// Tracking: link visits, onboarding funnel events, and charges (Dodo via the
// salahalarm-android Worker). App Store, Play and in-app purchases never count.
import { json, nowIso, dayOf, getCookie, cookie, classifyOs, isBot, randomToken } from './util.js';
import { resolveUsername, getAffiliate, balanceOf } from './store.js';
import { toUsd, intervalOf, commissionFor, MIN_PAYOUT_USD } from './commission.js';
import { capture, affiliateSet } from './posthog.js';

export const AFF_COOKIE_DAYS = 60;
const VISITOR_COOKIE = 'sa_vid';

// GET aff.internal/_visit/<username>  (only reachable through the site Worker's service binding)
// Answers 404 when the name isn't an affiliate, so the site shows its normal 404 page.
export async function handleVisit(request, env, ctx, username) {
  const aff = await resolveUsername(env, username);
  if (!aff) return new Response('not an affiliate', { status: 404 });
  const ua = request.headers.get('user-agent') || '';
  const existingVid = getCookie(request, VISITOR_COOKIE);
  const visitorId = existingVid && /^[\w-]{8,64}$/.test(existingVid) ? existingVid : crypto.randomUUID();
  const bot = isBot(ua) ? 1 : 0;
  const now = new Date();
  await env.DB.prepare(
    'INSERT INTO visits (affiliate_id, visitor_id, ts, day, country, os, referrer, is_bot) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
  ).bind(aff.id, visitorId, nowIso(now), dayOf(now), request.headers.get('x-aff-country') || request.cf?.country || null,
    classifyOs(ua), (request.headers.get('x-aff-referer') || request.headers.get('referer') || '').slice(0, 300) || null, bot).run();

  if (!bot) {
    capture(env, ctx, 'affiliate_link_visited', visitorId, { affiliate: aff.username, os: classifyOs(ua), $process_person_profile: false });
    if (!aff.first_visit_at) {
      await env.DB.prepare('UPDATE affiliates SET first_visit_at = ? WHERE id = ? AND first_visit_at IS NULL').bind(nowIso(), aff.id).run();
      capture(env, ctx, 'affiliate_first_visit', aff.email, { username: aff.username }, affiliateSet(env, aff));
    }
  }

  const url = new URL(request.url);
  const dest = new URL(env.LANDING_PATH || '/', env.MAIN_SITE || 'https://salahalarm.com');
  dest.searchParams.set('via', aff.username);
  for (const [k, v] of url.searchParams) if (k !== 'via') dest.searchParams.set(k, v);
  const headers = new Headers({ location: dest.pathname + dest.search, 'cache-control': 'no-store' });
  // Last click wins: a newer affiliate link replaces the older one.
  headers.append('set-cookie', cookie('sa_aff', aff.username, { maxAge: AFF_COOKIE_DAYS * 86400, httpOnly: false }));
  if (!existingVid) headers.append('set-cookie', cookie(VISITOR_COOKIE, visitorId, { maxAge: 365 * 86400 }));
  return new Response(null, { status: 302, headers });
}

// POST salahalarm.com/_aff/event (browser beacon, forwarded by the site Worker)
// body: { type: checkout_started | store_redirect, app_user_id?, platform?, plan? }
export async function handleBrowserEvent(request, env, ctx) {
  let body = {};
  try { body = JSON.parse(await request.text() || '{}'); } catch { /* sendBeacon text */ }
  const type = String(body.type || '');
  if (!['checkout_started', 'store_redirect', 'onboarding_started'].includes(type)) return json({ ok: false, error: 'unknown type' }, 400);
  const name = getCookie(request, 'sa_aff') || body.affiliate;
  const aff = name ? await resolveUsername(env, name) : null;
  if (!aff) return json({ ok: true, attributed: false });
  const visitorId = getCookie(request, VISITOR_COOKIE);
  const appUserId = cleanId(body.app_user_id);
  const platform = ['ios', 'android'].includes(body.platform) ? body.platform : null;

  if (appUserId) await attribute(env, appUserId, aff.id, visitorId, `browser:${type}`);
  const dedupe = `${type}:${aff.id}:${appUserId || visitorId || randomToken(8)}:${platform || ''}`;
  await env.DB.prepare(
    'INSERT OR IGNORE INTO events (affiliate_id, type, app_user_id, visitor_id, platform, plan, ts, dedupe_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
  ).bind(aff.id, type, appUserId, visitorId, platform, String(body.plan || '').slice(0, 40) || null, nowIso(), dedupe).run();

  if (type === 'store_redirect' && !aff.first_install_at) {
    await env.DB.prepare('UPDATE affiliates SET first_install_at = ? WHERE id = ? AND first_install_at IS NULL').bind(nowIso(), aff.id).run();
    capture(env, ctx, 'affiliate_first_install', aff.email, { username: aff.username }, affiliateSet(env, aff));
  }
  return json({ ok: true, attributed: true });
}

async function attribute(env, appUserId, affId, visitorId, source) {
  await env.DB.prepare(
    'INSERT OR IGNORE INTO attributions (app_user_id, affiliate_id, visitor_id, source, created_at) VALUES (?, ?, ?, ?, ?)'
  ).bind(appUserId, affId, visitorId || null, source, nowIso()).run();
}

const cleanId = (s) => (typeof s === 'string' && /^[\w:.\-$@]{1,128}$/.test(s) ? s : null);

async function affiliateFor(env, { affiliate, appUserIds = [] }) {
  if (affiliate) {
    const a = await resolveUsername(env, affiliate);
    if (a) return a;
  }
  for (const id of appUserIds.filter(Boolean)) {
    const row = await env.DB.prepare('SELECT affiliate_id FROM attributions WHERE app_user_id = ?').bind(id).first();
    if (row) {
      const a = await getAffiliate(env, row.affiliate_id);
      if (a && a.status === 'active') return a;
    }
  }
  return null;
}

// Records one charge. Idempotent on externalId.
export async function recordCharge(env, ctx, c) {
  const aff = await affiliateFor(env, { affiliate: c.affiliate, appUserIds: c.appUserIds });
  if (!aff) return { attributed: false };
  for (const id of c.appUserIds) if (id) await attribute(env, id, aff.id, null, `${c.source}:charge`);

  const interval = intervalOf({ interval: c.interval, product_id: c.productId, plan: c.plan });
  const { usd, estimated } = toUsd(c.amount, c.currency, c.amountUsd);
  // A first payment only earns once per customer: if we already credited one, treat later "firsts" as renewals.
  let kind = c.kind;
  if (kind === 'first' && c.appUserIds[0]) {
    const prior = await env.DB.prepare("SELECT 1 FROM conversions WHERE app_user_id = ? AND kind = 'first' AND external_id != ?")
      .bind(c.appUserIds[0], c.externalId).first();
    if (prior) kind = 'renewal';
  }
  const { commission, rule } = commissionFor({ interval, kind, amountUsd: usd });
  const status = commission > 0 ? 'pending' : 'no_commission';
  const res = await env.DB.prepare(`INSERT OR IGNORE INTO conversions
    (affiliate_id, external_id, source, kind, app_user_id, platform, product_id, interval, amount, currency, amount_usd, fx_estimated,
     commission_usd, rule, status, created_at, raw)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .bind(aff.id, c.externalId, c.source, kind, c.appUserIds[0] || null, c.platform || null, c.productId || null, interval,
      Number(c.amount) || 0, String(c.currency || 'USD').toUpperCase(), usd, estimated ? 1 : 0, commission, rule, status,
      c.at || nowIso(), JSON.stringify(c.raw || {}).slice(0, 4000)).run();
  const inserted = (res.meta?.changes ?? 1) > 0;
  return { attributed: true, inserted, affiliate: aff.username, kind, commission, status };
}

// Refunds: a pending charge is voided; an approved one gets a negative adjustment so the
// balance goes down (and comes off a later payout if it was already paid).
export async function recordRefund(env, externalId, refundUsd) {
  const conv = await env.DB.prepare('SELECT * FROM conversions WHERE external_id = ?').bind(externalId).first();
  if (!conv) return { found: false };
  if (conv.status === 'pending' || conv.status === 'no_commission') {
    await env.DB.prepare("UPDATE conversions SET status = 'refunded', decided_at = ? WHERE id = ?").bind(nowIso(), conv.id).run();
    return { found: true, voided: true };
  }
  if (conv.status === 'approved' && conv.commission_usd > 0) {
    const share = conv.amount_usd > 0 && refundUsd ? Math.min(1, refundUsd / conv.amount_usd) : 1;
    const back = -Math.round(conv.commission_usd * share * 100) / 100;
    await env.DB.prepare(`INSERT OR IGNORE INTO conversions
      (affiliate_id, external_id, source, kind, app_user_id, platform, product_id, interval, amount, currency, amount_usd, fx_estimated,
       commission_usd, rule, status, created_at, note)
      VALUES (?, ?, ?, 'refund', ?, ?, ?, ?, ?, ?, ?, 0, ?, 'refund of an approved sale', 'approved', ?, ?)`)
      .bind(conv.affiliate_id, `refund:${externalId}`, conv.source, conv.app_user_id, conv.platform, conv.product_id, conv.interval,
        -(refundUsd || conv.amount_usd), 'USD', -(refundUsd || conv.amount_usd), back, nowIso(), `refund of #${conv.id}`).run();
    return { found: true, clawback: back };
  }
  return { found: true };
}

// POST aff.internal/api/ingest  (salahalarm-android Worker, from the Dodo webhook, via service binding)
export async function handleIngest(request, env, ctx) {
  const b = await request.json().catch(() => null);
  if (!b || !b.type) return json({ ok: false, error: 'bad body' }, 400);
  const appUserId = cleanId(b.app_user_id);
  const ext = b.dodo_payment_id || b.payment_id || b.id;
  if (b.type === 'refunded') {
    if (!ext) return json({ ok: false, error: 'payment id required' }, 400);
    const { usd } = toUsd(b.refund_amount ?? b.amount, b.currency, b.refund_amount_usd);
    return json({ ok: true, ...(await recordRefund(env, `dodo:${ext}`, usd)) });
  }
  if (!['purchased', 'renewed'].includes(b.type)) return json({ ok: false, error: 'unknown type' }, 400);
  if (!ext) return json({ ok: false, error: 'payment id required' }, 400);
  const r = await recordCharge(env, ctx, {
    source: 'dodo', externalId: `dodo:${ext}`, kind: b.type === 'purchased' ? 'first' : 'renewal',
    affiliate: b.affiliate, appUserIds: [appUserId], platform: b.platform, productId: b.product_id, interval: b.interval,
    plan: b.plan, amount: b.amount, currency: b.currency, amountUsd: b.amount_usd, raw: b,
  });
  return json({ ok: true, ...r });
}

// Called after Om approves conversions: events for the email flows.
export async function afterApproval(env, ctx, affId, convs) {
  const aff = await getAffiliate(env, affId);
  if (!aff) return;
  const firstEver = await env.DB.prepare("SELECT COUNT(*) AS n FROM conversions WHERE affiliate_id = ? AND status = 'approved' AND commission_usd > 0").bind(affId).first();
  const before = firstEver.n - convs.length;
  convs.forEach((c, i) => capture(env, ctx, 'affiliate_conversion_approved', aff.email,
    { username: aff.username, amount_usd: c.commission_usd, plan: c.interval, is_first: before + i === 0 }, affiliateSet(env, aff)));
  const bal = await balanceOf(env, affId);
  if (bal >= MIN_PAYOUT_USD && !aff.payable_notified_at) {
    await env.DB.prepare('UPDATE affiliates SET payable_notified_at = ? WHERE id = ?').bind(nowIso(), affId).run();
    capture(env, ctx, 'affiliate_balance_payable', aff.email, { username: aff.username, balance_usd: bal }, affiliateSet(env, aff));
  }
}
