// Salah Alarm Affiliates: affiliate.salahalarm.com
// Portal (sign-up, dashboard, content library, FAQ), tracking endpoints, and Om's admin dashboard.
// Internal endpoints are only reachable through service bindings, which call https://aff.internal/...
import { html, json, redirect, readForm, isEmail, nowIso, randomToken, sha256 } from './util.js';
import {
  createSession, readSession, endSession, createLoginToken, useLoginToken, recentLoginTokens,
  checkPassword, adminPasswordHash, hashPassword,
} from './auth.js';
import {
  createAffiliate, getAffiliateByEmail, getAffiliate, affiliateStats, changeUsername, touch, balanceOf,
} from './store.js';
import { handleVisit, handleBrowserEvent, handleIngest, afterApproval } from './track.js';
import { capture, affiliateSet, sendLoginEmail } from './posthog.js';
import { commissionFor } from './commission.js';
import * as pub from './views/public.js';
import { dashboard } from './views/dashboard.js';
import * as adm from './views/admin.js';

const INTERNAL_HOST = 'aff.internal';

export async function app(request, env, ctx) {
  try {
    return await route(request, env, ctx);
  } catch (e) {
    console.error(e?.stack || e);
    return html('<h1>Something went wrong</h1><p>Please try again in a minute.</p>', { status: 500 });
  }
}


async function route(request, env, ctx) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const method = request.method;

  // Internal: service-binding calls from the salahalarm.com Workers.
  if (url.hostname === INTERNAL_HOST) {
    if (path.startsWith('/_visit/') && method === 'GET') return handleVisit(request, env, ctx, decodeURIComponent(path.slice(8)));
    if (path === '/_aff/event' && method === 'POST') return handleBrowserEvent(request, env, ctx);
    if (path === '/api/ingest' && method === 'POST') return handleIngest(request, env, ctx);
    return json({ ok: false }, 404);
  }

  if (path === '/healthz') return json({ ok: true });

  if (path === '/admin' || path.startsWith('/admin/')) return admin(request, env, ctx, url, path, method);

  if (method === 'POST' && !sameOrigin(request, url)) return html('Bad origin', { status: 403 });

  const session = await readSession(env, request, 'affiliate');
  const user = session ? await getAffiliate(env, session.affiliate_id) : null;

  switch (path) {
    case '/':
      return html(pub.landing({ user, msg: url.searchParams.get('m') }));
    case '/signup':
      if (method === 'POST') return signup(request, env, ctx, url);
      return redirect('/#join');
    case '/login':
      if (method === 'POST') return loginRequest(request, env, ctx, url);
      return html(pub.loginPage({ msg: url.searchParams.get('m') }));
    case '/logout':
      return redirect('/', 303, { 'set-cookie': await endSession(env, request, 'affiliate') });
    case '/content':
      return html(pub.contentIndex({ user, env }));
    case '/resources':
      return html(pub.resources({ user }));
    case '/faq':
      return html(pub.faqPage({ user }));
    case '/terms':
      return html(pub.termsPage({ user }));
    case '/robots.txt':
      return new Response('User-agent: *\nDisallow: /admin\nDisallow: /dashboard\n', { headers: { 'content-type': 'text/plain' } });
    default:
      break;
  }
  if (path.startsWith('/login/')) return loginWithToken(request, env, ctx, path.slice(7));
  if (path.startsWith('/content/')) {
    const out = pub.contentType({ user, env, slug: path.slice(9) });
    if (out) return html(out);
  }
  if (path === '/dashboard' || path.startsWith('/dashboard/')) {
    if (!user) return redirect('/login?m=' + encodeURIComponent('Log in to see your dashboard.'));
    return dashboardRoute(request, env, ctx, url, path, method, user);
  }
  return html(pub.notFound({ user }), { status: 404 });
}

function sameOrigin(request, url) {
  const origin = request.headers.get('origin');
  if (!origin) return true; // same-site form posts from old browsers; cookies are SameSite=Lax anyway
  try { return new URL(origin).host === url.host; } catch { return false; }
}

async function signup(request, env, ctx, url) {
  const form = await readForm(request);
  const email = String(form.email || '').trim().toLowerCase();
  if (!isEmail(email)) return redirect('/?m=' + encodeURIComponent('!Please enter a valid email address.') + '#join');
  const existing = await getAffiliateByEmail(env, email);
  if (existing) {
    // Never log someone into an existing account from the sign-up form: send a link instead.
    await sendLoginLink(env, ctx, url, existing);
    return redirect('/login?m=' + encodeURIComponent(`You already have an account. We've emailed a sign-in link to ${email}.`));
  }
  const aff = await createAffiliate(env, email);
  capture(env, ctx, 'affiliate_signed_up', aff.email, {
    username: aff.username, email: aff.email,
    link: `${env.MAIN_SITE || 'https://salahalarm.com'}/${aff.username}`,
    dashboard_url: `${portal(env, url)}/dashboard`,
  }, affiliateSet(env, aff));
  const setCookie = await createSession(env, { affiliateId: aff.id, role: 'affiliate' });
  return redirect('/dashboard?welcome=1', 303, { 'set-cookie': setCookie });
}

const portal = (env, url) => env.PORTAL_URL || `${url.protocol}//${url.host}`;

async function sendLoginLink(env, ctx, url, aff) {
  if ((await recentLoginTokens(env, aff.id)) >= 5) return false;
  const { token, expires } = await createLoginToken(env, aff.id);
  const loginUrl = `${portal(env, url)}/login/${token}`;
  capture(env, ctx, 'affiliate_login_requested', aff.email, { login_url: loginUrl, expires_at: expires, username: aff.username }, affiliateSet(env, aff));
  ctx?.waitUntil?.(sendLoginEmail(env, aff.email, loginUrl));
  return true;
}

async function loginRequest(request, env, ctx, url) {
  const form = await readForm(request);
  const email = String(form.email || '').trim().toLowerCase();
  if (!isEmail(email)) return html(pub.loginPage({ msg: 'Please enter a valid email address.', kind: 'bad', email }), { status: 400 });
  const aff = await getAffiliateByEmail(env, email);
  if (aff && aff.status === 'active') await sendLoginLink(env, ctx, url, aff);
  // Same answer whether or not the email exists.
  return html(pub.loginPage({ msg: `If ${email} has an account, a sign-in link is on its way. It works once and expires in 30 minutes.`, email }));
}

async function loginWithToken(request, env, ctx, token) {
  const affId = await useLoginToken(env, token);
  if (!affId) return html(pub.loginPage({ msg: 'That sign-in link has expired or was already used. Enter your email for a new one.', kind: 'bad' }), { status: 400 });
  await touch(env, affId);
  return redirect('/dashboard', 303, { 'set-cookie': await createSession(env, { affiliateId: affId, role: 'affiliate' }) });
}

async function dashboardRoute(request, env, ctx, url, path, method, aff) {
  if (method === 'POST') {
    const form = await readForm(request);
    let msg = '';
    let kind = 'ok';
    if (path === '/dashboard/payout') {
      const m = String(form.method || '');
      const details = String(form.details || '').trim().slice(0, 200);
      if (!['wise', 'paypal', 'payoneer'].includes(m) || !details) { msg = 'Choose Wise, PayPal or Payoneer and enter your account email or ID.'; kind = 'bad'; } else {
        await env.DB.prepare('UPDATE affiliates SET payout_method = ?, payout_details = ? WHERE id = ?').bind(m, details, aff.id).run();
        msg = 'Payout details saved.';
      }
    } else if (path === '/dashboard/post') {
      const u = String(form.url || '').trim();
      let ok = false;
      try { ok = /^https?:$/.test(new URL(u).protocol) && u.length <= 500; } catch { ok = false; }
      if (!ok) { msg = 'Paste the full link to your post (starting with https://).'; kind = 'bad'; } else {
        const host = new URL(u).hostname.replace(/^www\./, '');
        const platform = /tiktok/.test(host) ? 'tiktok' : /instagram/.test(host) ? 'instagram' : /youtu/.test(host) ? 'youtube' : host;
        const prior = await env.DB.prepare('SELECT COUNT(*) AS n FROM posts WHERE affiliate_id = ?').bind(aff.id).first();
        await env.DB.prepare('INSERT INTO posts (affiliate_id, url, platform, content_type, created_at) VALUES (?, ?, ?, ?, ?)')
          .bind(aff.id, u, platform, String(form.content_type || '').slice(0, 40) || null, nowIso()).run();
        capture(env, ctx, 'affiliate_post_submitted', aff.email, { username: aff.username, url: u, platform, is_first: prior.n === 0 }, affiliateSet(env, aff));
        msg = 'Post logged. Keep going!';
      }
    } else if (path === '/dashboard/username') {
      const r = await changeUsername(env, aff, form.username);
      if (r.error) { msg = r.error; kind = 'bad'; } else msg = `Your username is now ${r.username}. Your old link still works.`;
    }
    await touch(env, aff.id);
    return redirect(`/dashboard?m=${encodeURIComponent(msg)}&k=${kind}`);
  }
  const fresh = await getAffiliate(env, aff.id);
  const day = new Date().toISOString().slice(0, 10);
  if (!fresh.last_active_at || fresh.last_active_at.slice(0, 10) !== day) {
    capture(env, ctx, 'affiliate_active_day', fresh.email, { username: fresh.username }, affiliateSet(env, fresh));
  }
  await touch(env, aff.id);
  const [stats, sales, payouts, posts] = await Promise.all([
    affiliateStats(env, aff.id),
    env.DB.prepare("SELECT * FROM conversions WHERE affiliate_id = ? AND status = 'approved' ORDER BY created_at DESC LIMIT 100").bind(aff.id).all(),
    env.DB.prepare('SELECT * FROM payouts WHERE affiliate_id = ? ORDER BY created_at DESC').bind(aff.id).all(),
    env.DB.prepare('SELECT * FROM posts WHERE affiliate_id = ? ORDER BY created_at DESC LIMIT 20').bind(aff.id).all(),
  ]);
  return html(dashboard({
    env, aff: fresh, stats, sales: sales.results, payouts: payouts.results, posts: posts.results,
    msg: url.searchParams.get('m'), kind: url.searchParams.get('k') === 'bad' ? 'bad' : 'ok', welcome: url.searchParams.has('welcome'),
  }));
}

// ---------- Admin ----------

async function admin(request, env, ctx, url, path, method) {
  if (method === 'POST' && !sameOrigin(request, url)) return html('Bad origin', { status: 403 });
  if (path === '/admin/login') {
    if (method !== 'POST') return html(adm.adminLogin({}));
    const form = await readForm(request);
    const ok = await checkPassword(String(form.password || ''), await adminPasswordHash(env));
    if (!ok) return html(adm.adminLogin({ msg: 'Wrong password.' }), { status: 401 });
    return redirect('/admin', 303, { 'set-cookie': await createSession(env, { role: 'admin' }) });
  }
  const session = await readSession(env, request, 'admin');
  if (!session) return redirect('/admin/login');
  if (path === '/admin/logout') return redirect('/admin/login', 303, { 'set-cookie': await endSession(env, request, 'admin') });

  const msg = url.searchParams.get('m');
  if (path === '/admin') {
    const range = ['7', '30', 'all'].includes(url.searchParams.get('range')) ? url.searchParams.get('range') : '30';
    return html(adm.adminOverview({ ...(await overview(env, range)), msg, range }));
  }
  if (path === '/admin/export.csv') return exportCsv(env);
  if (path === '/admin/review') {
    const pending = await env.DB.prepare("SELECT c.*, a.username FROM conversions c JOIN affiliates a ON a.id = c.affiliate_id WHERE c.status = 'pending' ORDER BY c.created_at").all();
    const recent = await env.DB.prepare("SELECT c.*, a.username FROM conversions c JOIN affiliates a ON a.id = c.affiliate_id WHERE c.status IN ('approved','rejected','refunded') ORDER BY COALESCE(c.decided_at, c.created_at) DESC LIMIT 50").all();
    return html(adm.adminReview({ pending: pending.results, recent: recent.results, msg }));
  }
  if (path === '/admin/conversions/decide' && method === 'POST') {
    const form = await readForm(request);
    const decision = form.decision === 'approved' ? 'approved' : form.decision === 'rejected' ? 'rejected' : null;
    const ids = [].concat(form.ids || []).map(Number).filter((n) => Number.isInteger(n) && n > 0);
    if (!decision || !ids.length) return redirect('/admin/review?m=' + encodeURIComponent('Select at least one conversion.'));
    const now = nowIso();
    const changed = [];
    for (const id of ids) {
      const c = await env.DB.prepare('SELECT * FROM conversions WHERE id = ?').bind(id).first();
      if (!c || c.payout_id) continue;
      const allowed = decision === 'approved' ? c.status === 'pending' : ['pending', 'approved'].includes(c.status);
      if (!allowed) continue;
      await env.DB.prepare('UPDATE conversions SET status = ?, decided_at = ? WHERE id = ?').bind(decision, now, id).run();
      changed.push(c);
    }
    if (decision === 'approved') {
      const byAff = {};
      for (const c of changed) (byAff[c.affiliate_id] ||= []).push(c);
      for (const [affId, list] of Object.entries(byAff)) await afterApproval(env, ctx, Number(affId), list);
    }
    const back = request.headers.get('referer')?.includes('/admin/affiliates/') ? new URL(request.headers.get('referer')).pathname : '/admin/review';
    return redirect(`${back}?m=${encodeURIComponent(`${changed.length} conversion${changed.length === 1 ? '' : 's'} ${decision}.`)}`);
  }
  const m = path.match(/^\/admin\/affiliates\/(\d+)(?:\/(payout|manual|status))?$/);
  if (m) {
    const aff = await getAffiliate(env, Number(m[1]));
    if (!aff) return html(adm.adminLogin({ msg: 'No such affiliate.' }), { status: 404 });
    if (m[2] && method === 'POST') return affiliateAction(request, env, ctx, aff, m[2]);
    const [stats, convs, payouts, posts, ev] = await Promise.all([
      affiliateStats(env, aff.id),
      env.DB.prepare('SELECT * FROM conversions WHERE affiliate_id = ? ORDER BY created_at DESC LIMIT 300').bind(aff.id).all(),
      env.DB.prepare('SELECT * FROM payouts WHERE affiliate_id = ? ORDER BY created_at DESC').bind(aff.id).all(),
      env.DB.prepare('SELECT * FROM posts WHERE affiliate_id = ? ORDER BY created_at DESC LIMIT 100').bind(aff.id).all(),
      env.DB.prepare("SELECT COUNT(*) AS n FROM events WHERE affiliate_id = ? AND type = 'checkout_started'").bind(aff.id).first(),
    ]);
    return html(adm.adminAffiliate({ aff, stats, convs: convs.results, payouts: payouts.results, posts: posts.results, events: { checkouts: ev.n }, msg }));
  }
  if (path === '/admin/payouts') {
    const all = await env.DB.prepare("SELECT * FROM affiliates ORDER BY id").all();
    const due = [];
    for (const a of all.results) {
      const balance = await balanceOf(env, a.id);
      if (balance >= 100) due.push({ ...a, balance });
    }
    const history = await env.DB.prepare('SELECT p.*, a.username FROM payouts p JOIN affiliates a ON a.id = p.affiliate_id ORDER BY p.created_at DESC LIMIT 200').all();
    return html(adm.adminPayouts({ due, history: history.results, msg }));
  }
  if (path === '/admin/settings') {
    return html(adm.adminSettings({ msg, kind: url.searchParams.get('k') === 'bad' ? 'bad' : 'ok' }));
  }
  if (path === '/admin/settings/password' && method === 'POST') {
    const form = await readForm(request);
    if (!(await checkPassword(String(form.current || ''), await adminPasswordHash(env)))) return redirect('/admin/settings?k=bad&m=' + encodeURIComponent('Current password is wrong.'));
    const next = String(form.next || '');
    if (next.length < 12) return redirect('/admin/settings?k=bad&m=' + encodeURIComponent('Use at least 12 characters.'));
    await env.DB.prepare("INSERT INTO settings (key, value) VALUES ('admin_password_hash', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value").bind(await hashPassword(next)).run();
    return redirect('/admin/settings?m=' + encodeURIComponent('Password changed.'));
  }
  return redirect('/admin');
}

async function affiliateAction(request, env, ctx, aff, action) {
  const form = await readForm(request);
  const back = (m) => redirect(`/admin/affiliates/${aff.id}?m=${encodeURIComponent(m)}`);
  if (action === 'payout') {
    const amount = Math.round(Number(form.amount) * 100) / 100;
    const balance = await balanceOf(env, aff.id);
    if (!(amount > 0) || amount > balance + 0.001) return back(`Amount must be between $0.01 and the balance (${balance.toFixed(2)}).`);
    const res = await env.DB.prepare('INSERT INTO payouts (affiliate_id, amount_usd, method, reference, created_at) VALUES (?, ?, ?, ?, ?) RETURNING id')
      .bind(aff.id, amount, aff.payout_method, String(form.reference || '').slice(0, 120) || null, nowIso()).first();
    await env.DB.prepare("UPDATE conversions SET payout_id = ? WHERE affiliate_id = ? AND status = 'approved' AND payout_id IS NULL").bind(res.id, aff.id).run();
    await env.DB.prepare('UPDATE affiliates SET payable_notified_at = NULL WHERE id = ?').bind(aff.id).run();
    capture(env, ctx, 'affiliate_payout_sent', aff.email, { username: aff.username, amount_usd: amount, method: aff.payout_method }, affiliateSet(env, aff));
    const ref = request.headers.get('referer') || '';
    if (ref.includes('/admin/payouts')) return redirect('/admin/payouts?m=' + encodeURIComponent(`Marked $${amount.toFixed(2)} paid to ${aff.username}.`));
    return back(`Marked $${amount.toFixed(2)} as paid.`);
  }
  if (action === 'manual') {
    const amount = Math.max(0, Number(form.amount) || 0);
    const interval = ['year', 'week', 'lifetime'].includes(form.interval) ? form.interval : 'year';
    const { commission, rule } = commissionFor({ interval, kind: 'first', amountUsd: amount });
    await env.DB.prepare(`INSERT INTO conversions (affiliate_id, external_id, source, kind, interval, amount, currency, amount_usd, commission_usd, rule, status, created_at, decided_at, note)
      VALUES (?, ?, 'manual', 'first', ?, ?, 'USD', ?, ?, ?, 'approved', ?, ?, ?)`)
      .bind(aff.id, `manual:${await sha256(randomToken(12))}`, interval, amount, amount, commission, rule, nowIso(), nowIso(), String(form.note || '').slice(0, 200) || null).run();
    await afterApproval(env, ctx, aff.id, [{ commission_usd: commission, interval }]);
    return back(`Added a $${amount.toFixed(2)} ${interval} sale ($${commission.toFixed(2)} commission).`);
  }
  if (action === 'status') {
    const status = form.status === 'blocked' ? 'blocked' : 'active';
    await env.DB.prepare('UPDATE affiliates SET status = ?, note = ? WHERE id = ?').bind(status, String(form.note || '').slice(0, 300) || null, aff.id).run();
    return back(status === 'blocked' ? 'Affiliate blocked. Their link now shows the normal site 404.' : 'Saved.');
  }
  return back('');
}

async function overview(env, range) {
  const since = range === 'all' ? '0000' : new Date(Date.now() - Number(range) * 864e5).toISOString();
  const all = (sql, ...b) => env.DB.prepare(sql).bind(...b).all().then((r) => r.results);
  const [affs, visits, events, convs, money, paid, posts] = await Promise.all([
    all('SELECT * FROM affiliates ORDER BY created_at DESC'),
    all('SELECT affiliate_id, COUNT(*) AS n FROM visits WHERE is_bot = 0 AND ts >= ? GROUP BY affiliate_id', since),
    all('SELECT affiliate_id, type, COUNT(*) AS n FROM events WHERE ts >= ? GROUP BY affiliate_id, type', since),
    all("SELECT affiliate_id, COUNT(*) AS n, COALESCE(SUM(amount_usd),0) AS revenue FROM conversions WHERE kind IN ('first','renewal') AND status != 'rejected' AND created_at >= ? GROUP BY affiliate_id", since),
    all("SELECT affiliate_id, status, COALESCE(SUM(commission_usd),0) AS c, COUNT(*) AS n FROM conversions GROUP BY affiliate_id, status"),
    all('SELECT affiliate_id, COALESCE(SUM(amount_usd),0) AS p FROM payouts GROUP BY affiliate_id'),
    all('SELECT affiliate_id, COUNT(*) AS n FROM posts GROUP BY affiliate_id'),
  ]);
  const by = (arr, key = 'affiliate_id') => Object.fromEntries(arr.map((r) => [r[key], r]));
  const v = by(visits), c = by(convs), p = by(paid), po = by(posts);
  const ev = {};
  for (const e of events) (ev[e.affiliate_id] ||= {})[e.type] = e.n;
  const mo = {};
  for (const m of money) (mo[m.affiliate_id] ||= {})[m.status] = m;
  const r2 = (n) => Math.round((Number(n) || 0) * 100) / 100;
  const rows = affs.map((a) => {
    const approved = mo[a.id]?.approved?.c || 0;
    const paidOut = p[a.id]?.p || 0;
    return {
      ...a, visits: v[a.id]?.n || 0, checkouts: ev[a.id]?.checkout_started || 0, downloads: ev[a.id]?.store_redirect || 0,
      charges: c[a.id]?.n || 0, revenue: r2(c[a.id]?.revenue), pending: r2(mo[a.id]?.pending?.c), balance: r2(approved - paidOut),
      paid: r2(paidOut), posts: po[a.id]?.n || 0,
    };
  });
  const sum = (k) => rows.reduce((s, r) => s + (Number(r[k]) || 0), 0);
  const pendingCount = money.filter((m) => m.status === 'pending').reduce((s, m) => s + m.n, 0);
  return {
    rows,
    totals: {
      affiliates: rows.length, visits: sum('visits'), checkouts: sum('checkouts'), downloads: sum('downloads'), charges: sum('charges'),
      revenue: r2(sum('revenue')), pending: r2(sum('pending')), owed: r2(sum('balance')), paid: r2(sum('paid')), pendingCount,
    },
  };
}

async function exportCsv(env) {
  const rows = await env.DB.prepare(`SELECT c.id, c.created_at, a.username, a.email, c.source, c.kind, c.platform, c.interval, c.amount, c.currency,
    c.amount_usd, c.commission_usd, c.status, c.payout_id, c.app_user_id, c.external_id FROM conversions c JOIN affiliates a ON a.id = c.affiliate_id ORDER BY c.created_at`).all();
  const cols = ['id', 'created_at', 'username', 'email', 'source', 'kind', 'platform', 'interval', 'amount', 'currency', 'amount_usd', 'commission_usd', 'status', 'payout_id', 'app_user_id', 'external_id'];
  const q = (v) => {
    const s = String(v ?? '');
    return /[",\n]/.test(s) || /^[=+@]/.test(s) ? `"${s.replace(/^([=+@])/, "'$1").replace(/"/g, '""')}"` : s;
  };
  const body = [cols.join(','), ...rows.results.map((r) => cols.map((k) => q(r[k])).join(','))].join('\n');
  return new Response(body, { headers: { 'content-type': 'text/csv; charset=utf-8', 'content-disposition': 'attachment; filename="affiliate-conversions.csv"', 'cache-control': 'no-store' } });
}

export default { fetch: app };
