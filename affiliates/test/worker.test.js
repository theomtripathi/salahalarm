import { test } from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/worker.js';
import { makeDb } from './d1-shim.js';
import { hashPassword } from '../src/auth.js';
import { commissionFor, intervalOf, toUsd } from '../src/commission.js';
import { baseUsername, validUsername } from '../src/store.js';
import { makkahPrompt, daysUntil, numberWords } from '../src/content-data.js';
import { nextPayoutDate } from '../src/util.js';

const PW = 'test-admin-password-123';
const sent = [];
globalThis.fetch = async (url, init) => { sent.push({ url: String(url), body: init?.body ? JSON.parse(init.body) : null }); return new Response('{}'); };

async function setup() {
  const env = { DB: makeDb(), POSTHOG_KEY: 'phc_test', ADMIN_PASSWORD_HASH: await hashPassword(PW), MAIN_SITE: 'https://salahalarm.com', PORTAL_URL: 'https://affiliate.salahalarm.com' };
  const ctx = { waitUntil: () => {} };
  const jar = {};
  const call = async (path, { method = 'GET', form, json, host = 'affiliate.salahalarm.com', headers = {}, cookies = jar } = {}) => {
    const h = new Headers(headers);
    const ck = Object.entries(cookies).map(([k, v]) => `${k}=${v}`).join('; ');
    if (ck) h.set('cookie', ck);
    let body;
    if (form) { body = new URLSearchParams(form); h.set('content-type', 'application/x-www-form-urlencoded'); }
    if (json) { body = JSON.stringify(json); h.set('content-type', 'application/json'); }
    const res = await worker.fetch(new Request(`https://${host}${path}`, { method, headers: h, body, redirect: 'manual' }), env, ctx);
    for (const c of res.headers.getSetCookie?.() || []) {
      const [kv] = c.split(';'); const i = kv.indexOf('=');
      cookies[kv.slice(0, i)] = kv.slice(i + 1);
    }
    return res;
  };
  return { env, call, jar };
}

test('commission rules', () => {
  assert.equal(commissionFor({ interval: 'year', kind: 'first', amountUsd: 40 }).commission, 3.33);
  assert.equal(commissionFor({ interval: 'week', kind: 'first', amountUsd: 5.99 }).commission, 3);
  assert.equal(commissionFor({ interval: 'week', kind: 'renewal', amountUsd: 5.99 }).commission, 0);
  assert.equal(commissionFor({ interval: 'year', kind: 'renewal', amountUsd: 40 }).commission, 0);
  assert.equal(intervalOf({ product_id: 'com.ramadanpro.yearly.discount' }), 'year');
  assert.equal(intervalOf({ product_id: 'salah_weekly_599' }), 'week');
  assert.deepEqual(toUsd(10, 'GBP'), { usd: 12.7, estimated: true });
  assert.deepEqual(toUsd(29.99, 'USD'), { usd: 29.99, estimated: false });
});

test('usernames', () => {
  assert.equal(baseUsername('Aisha.Khan+tt@gmail.com'), 'aishakhan');
  assert.equal(validUsername('admin'), false);
  assert.equal(validUsername('ramadan-2027'), false);
  assert.equal(validUsername('go'), false);
  assert.equal(validUsername('123'), false);
  assert.equal(validUsername('fajr_sara'), true);
});

test('dates and prompt', () => {
  assert.equal(daysUntil('2027-02-08', new Date('2026-11-09T10:00:00Z')), 91);
  assert.equal(numberWords(91), 'ninety-one');
  const p = makkahPrompt({ loggedIn: true, username: 'sara_k', link: 'salahalarm.com/sara_k', linkUrl: 'https://salahalarm.com/sara_k', daysToRamadan: 87, daysWords: 'eighty-seven' });
  assert.match(p, /Eighty-seven days from now, Ramadan begins/);
  assert.match(p, /Salah Alarm dot com slash sara underscore k/);
  assert.match(p, /QR code encoding https:\/\/salahalarm.com\/sara_k/);
  assert.equal(nextPayoutDate(new Date('2026-11-13T00:00:00Z')).toISOString().slice(0, 10), '2026-11-16');
  assert.equal(nextPayoutDate(new Date('2026-11-20T00:00:00Z')).toISOString().slice(0, 10), '2026-12-01');
});

test('public pages never spell out the link format', async () => {
  const { call } = await setup();
  for (const p of ['/', '/content', '/content/clipping', '/content/makkah-trip-story', '/faq', '/terms', '/resources']) {
    const res = await call(p, { cookies: {} });
    assert.equal(res.status, 200, p);
    const text = await res.text();
    assert.doesNotMatch(text, /salahalarm\.com\/(username|your-?name|<)/i, p);
    assert.doesNotMatch(text, /salahalarm\.com\/\[/i, p);
  }
});

test('full flow: sign up, visit, checkout, Dodo purchase, approval, payout', async () => {
  const { env, call, jar } = await setup();

  // Sign up with just an email -> logged in with a link.
  let res = await call('/signup', { method: 'POST', form: { email: 'Sara.K@example.com' } });
  assert.equal(res.status, 303);
  assert.equal(res.headers.get('location'), '/dashboard?welcome=1');
  res = await call('/dashboard?welcome=1');
  let page = await res.text();
  assert.match(page, /salahalarm\.com\/sarak/);
  assert.ok(sent.some((s) => s.body?.event === 'affiliate_signed_up' && s.body.distinct_id === 'sara.k@example.com'));

  // Same email again: no login, a sign-in link instead.
  const other = {};
  res = await call('/signup', { method: 'POST', form: { email: 'sara.k@example.com' }, cookies: other });
  assert.match(res.headers.get('location'), /^\/login\?m=/);
  assert.equal(other.aff_s, undefined);
  const loginEvt = sent.filter((s) => s.body?.event === 'affiliate_login_requested').pop();
  assert.ok(loginEvt.body.properties.login_url.startsWith('https://affiliate.salahalarm.com/login/'));
  const tokenPath = new URL(loginEvt.body.properties.login_url).pathname;
  res = await call(tokenPath, { cookies: other });
  assert.equal(res.headers.get('location'), '/dashboard');
  res = await call(tokenPath, { cookies: {} });
  assert.equal(res.status, 400, 'token is single use');

  // Visit through the site Worker's service binding.
  const visitor = { sa_vid: 'visitor-1234' };
  res = await call('/_visit/sarak?utm_source=tt', { host: 'aff.internal', headers: { 'user-agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)' }, cookies: visitor });
  assert.equal(res.status, 302);
  assert.equal(res.headers.get('location'), '/?via=sarak&utm_source=tt');
  assert.equal(visitor.sa_aff, 'sarak');
  res = await call('/_visit/nobody_here', { host: 'aff.internal', cookies: {} });
  assert.equal(res.status, 404);
  // Internal endpoints are not public.
  res = await call('/_visit/sarak', { cookies: {} });
  assert.equal(res.status, 404);

  // Browser beacons from the onboarding flow.
  res = await call('/_aff/event', { host: 'aff.internal', method: 'POST', json: { type: 'checkout_started', app_user_id: 'uid_abc', platform: 'ios', plan: 'yearly' }, cookies: visitor });
  assert.deepEqual(await res.json(), { ok: true, attributed: true });
  await call('/_aff/event', { host: 'aff.internal', method: 'POST', json: { type: 'store_redirect', app_user_id: 'uid_abc', platform: 'ios' }, cookies: visitor });
  await call('/_aff/event', { host: 'aff.internal', method: 'POST', json: { type: 'store_redirect', app_user_id: 'uid_abc', platform: 'ios' }, cookies: visitor });

  // Dodo purchase via the android Worker (no affiliate in metadata: falls back to the attribution).
  res = await call('/api/ingest', { host: 'aff.internal', method: 'POST', json: { type: 'purchased', app_user_id: 'uid_abc', amount: 39.99, currency: 'USD', interval: 'year', product_id: 'yearly', dodo_payment_id: 'pay_1', platform: 'ios' } });
  let r = await res.json();
  assert.equal(r.attributed, true);
  assert.equal(r.commission, 3.33);
  assert.equal(r.status, 'pending');
  // Duplicate webhook is ignored.
  r = await (await call('/api/ingest', { host: 'aff.internal', method: 'POST', json: { type: 'purchased', app_user_id: 'uid_abc', amount: 39.99, currency: 'USD', interval: 'year', dodo_payment_id: 'pay_1' } })).json();
  assert.equal(r.inserted, false);
  // Renewal earns nothing.
  r = await (await call('/api/ingest', { host: 'aff.internal', method: 'POST', json: { type: 'renewed', app_user_id: 'uid_abc', amount: 39.99, currency: 'USD', interval: 'year', dodo_payment_id: 'pay_2' } })).json();
  assert.equal(r.status, 'no_commission');
  // Weekly buyer with affiliate in metadata.
  r = await (await call('/api/ingest', { host: 'aff.internal', method: 'POST', json: { type: 'purchased', app_user_id: 'uid_w', affiliate: 'SaraK', amount: 5.99, currency: 'USD', interval: 'week', dodo_payment_id: 'pay_3' } })).json();
  assert.equal(r.commission, 3);
  // Unattributed purchase.
  r = await (await call('/api/ingest', { host: 'aff.internal', method: 'POST', json: { type: 'purchased', app_user_id: 'uid_none', amount: 5.99, currency: 'USD', interval: 'week', dodo_payment_id: 'pay_4' } })).json();
  assert.equal(r.attributed, false);

  // Affiliate sees nothing until approval.
  page = await (await call('/dashboard')).text();
  assert.match(page, /No approved sales yet/);
  assert.match(page, />2<\/div><div class="k">Downloads|>1<\/div><div class="k">Downloads/);

  // Admin: wrong password, then right.
  const adminJar = {};
  res = await call('/admin/login', { method: 'POST', form: { password: 'nope' }, cookies: adminJar });
  assert.equal(res.status, 401);
  res = await call('/admin/login', { method: 'POST', form: { password: PW }, cookies: adminJar });
  assert.equal(res.headers.get('location'), '/admin');
  page = await (await call('/admin?range=all', { cookies: adminJar })).text();
  assert.match(page, /sarak/);
  assert.match(page, /2 conversions waiting for approval/);
  page = await (await call('/admin/review', { cookies: adminJar })).text();
  const ids = [...page.matchAll(/name="ids" value="(\d+)"/g)].map((m) => m[1]);
  assert.equal(ids.length, 2);
  const form = new URLSearchParams(); ids.forEach((i) => form.append('ids', i)); form.set('decision', 'approved');
  res = await worker.fetch(new Request('https://affiliate.salahalarm.com/admin/conversions/decide', { method: 'POST', body: form, headers: { cookie: `aff_admin=${adminJar.aff_admin}`, 'content-type': 'application/x-www-form-urlencoded' } }), env, { waitUntil() {} });
  assert.equal(res.status, 303);
  assert.ok(sent.some((s) => s.body?.event === 'affiliate_conversion_approved' && s.body.properties.is_first === true));

  page = await (await call('/dashboard')).text();
  assert.match(page, /\$6\.33/);

  // Non-admins can't reach admin pages.
  res = await call('/admin', { cookies: {} });
  assert.equal(res.headers.get('location'), '/admin/login');
  res = await call('/admin', { cookies: { aff_admin: jar.aff_s } });
  assert.equal(res.headers.get('location'), '/admin/login');

  // Refund of an approved sale claws it back.
  r = await (await call('/api/ingest', { host: 'aff.internal', method: 'POST', json: { type: 'refunded', dodo_payment_id: 'pay_3', amount: 5.99, currency: 'USD' } })).json();
  assert.equal(r.clawback, -3);

  // Payout.
  const affId = env.DB.raw.prepare('SELECT id FROM affiliates').get().id;
  res = await call(`/admin/affiliates/${affId}/payout`, { method: 'POST', form: { amount: '3.33', reference: 'T1' }, cookies: adminJar });
  assert.match(res.headers.get('location'), /Marked/);
  page = await (await call('/dashboard')).text();
  assert.match(page, /Paid out/);
  res = await call(`/admin/affiliates/${affId}/payout`, { method: 'POST', form: { amount: '50' }, cookies: adminJar });
  assert.match(decodeURIComponent(res.headers.get('location')), /Amount must be/);

  // CSV export.
  res = await call('/admin/export.csv', { cookies: adminJar });
  assert.match(await res.text(), /^id,created_at,username/);
});

test('RevenueCat webhook', async () => {
  const { env, call } = await setup();
  await call('/signup', { method: 'POST', form: { email: 'ali@example.com' } });
  const adminJar = {};
  await call('/admin/login', { method: 'POST', form: { password: PW }, cookies: adminJar });
  const settings = await (await call('/admin/settings', { cookies: adminJar })).text();
  const auth = settings.match(/value="(Bearer [^"]+)"/)[1];
  const evt = (e) => call('/api/revenuecat', { method: 'POST', json: { event: e }, headers: { authorization: auth }, cookies: {} });
  assert.equal((await call('/api/revenuecat', { method: 'POST', json: { event: {} }, cookies: {} })).status, 401);
  let r = await (await evt({ id: 'e1', type: 'INITIAL_PURCHASE', app_user_id: 'u9', price: 5.99, product_id: 'weekly', store: 'APP_STORE', subscriber_attributes: { affiliate: { value: 'ali' } }, transaction_id: 't1' })).json();
  assert.equal(r.commission, 3);
  r = await (await evt({ id: 'e2', type: 'INITIAL_PURCHASE', app_user_id: 'u9', price: 29.99, product_id: 'x', store: 'PROMOTIONAL' })).json();
  assert.equal(r.ignored, 'PROMOTIONAL');
  r = await (await evt({ id: 'e3', type: 'RENEWAL', app_user_id: 'u9', price: 5.99, product_id: 'weekly', store: 'APP_STORE', transaction_id: 't2' })).json();
  assert.equal(r.status, 'no_commission');
  r = await (await evt({ id: 'e4', type: 'CANCELLATION', cancel_reason: 'CUSTOMER_SUPPORT', app_user_id: 'u9', price: -5.99, transaction_id: 't1', original_transaction_id: 't1' })).json();
  assert.equal(r.voided, true);
});
