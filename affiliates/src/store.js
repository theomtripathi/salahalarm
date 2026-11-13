// Data access for affiliates, their links and their numbers.
import { nowIso } from './util.js';
import { MIN_PAYOUT_USD } from './commission.js';

// Top-level paths already used (or likely to be used) on salahalarm.com, plus words that
// would look official. An affiliate can never take these as a username.
export const RESERVED = new Set(`
go c get android api download downloads assets blog ramadan ramadan-2027 ramadan2027 rules privacy terms support
admin administrator affiliate affiliates partner partners help faq about contact login logout signup register
dashboard account settings app apps ios iphone ipad play store appstore pay paywall checkout payment payments billing
subscribe subscription offer offers discount promo invite invites join challenge makkah umrah draw prize winner
sitemap robots favicon index home www mail email static img images css js fonts media cdn api2 dev test staging
salah salahalarm salah_alarm salahalarm_app official team staff om owner founder news press careers jobs legal
onboarding start welcome quiz plan plans pricing price trial free gift seat seats share s r u a l x
`.split(/\s+/).filter(Boolean));

export function normalizeUsername(s) {
  return String(s || '').toLowerCase().trim().replace(/[^a-z0-9_]/g, '');
}

export function validUsername(u) {
  return /^[a-z0-9_]{3,24}$/.test(u) && /[a-z]/.test(u) && !RESERVED.has(u) && !/^_|_$/.test(u);
}

// Username from the email's local part: "Aisha.Khan+tt@x.com" -> "aishakhan".
export function baseUsername(email) {
  let u = normalizeUsername(String(email).split('@')[0].split('+')[0].replace(/[.\-]/g, ''));
  if (!/[a-z]/.test(u)) u = `a${u}`;
  u = u.slice(0, 18);
  while (u.length < 3) u += 'x';
  if (RESERVED.has(u)) u = `${u}_`.slice(0, 18) + 'x';
  return u.replace(/_+$/, '') || 'affiliate';
}

export async function usernameTaken(env, u) {
  const r = await env.DB.prepare('SELECT 1 FROM usernames WHERE username = ?').bind(u).first();
  return Boolean(r);
}

export async function freeUsername(env, email) {
  const base = baseUsername(email);
  if (validUsername(base) && !(await usernameTaken(env, base))) return base;
  for (let i = 0; i < 50; i++) {
    const n = i < 20 ? String(i + 2) : String(Math.floor(100 + Math.random() * 900));
    const u = `${base.slice(0, 24 - n.length)}${n}`;
    if (validUsername(u) && !(await usernameTaken(env, u))) return u;
  }
  return `aff${Date.now().toString(36)}`;
}

export async function getAffiliateByEmail(env, email) {
  return env.DB.prepare('SELECT * FROM affiliates WHERE email = ?').bind(email.toLowerCase()).first();
}

export async function getAffiliate(env, id) {
  return env.DB.prepare('SELECT * FROM affiliates WHERE id = ?').bind(id).first();
}

// Resolves current or old usernames. Blocked affiliates don't resolve.
export async function resolveUsername(env, u) {
  const name = normalizeUsername(u);
  if (!name) return null;
  return env.DB.prepare(
    "SELECT a.* FROM usernames n JOIN affiliates a ON a.id = n.affiliate_id WHERE n.username = ? AND a.status = 'active'"
  ).bind(name).first();
}

export async function createAffiliate(env, email) {
  const now = nowIso();
  const lower = email.toLowerCase();
  for (let attempt = 0; attempt < 3; attempt++) {
    const username = await freeUsername(env, lower);
    try {
      const res = await env.DB.prepare(
        'INSERT INTO affiliates (email, username, created_at, last_active_at) VALUES (?, ?, ?, ?) RETURNING id'
      ).bind(lower, username, now, now).first();
      await env.DB.prepare('INSERT INTO usernames (username, affiliate_id, created_at) VALUES (?, ?, ?)')
        .bind(username, res.id, now).run();
      return { id: res.id, email: lower, username, created_at: now };
    } catch (e) {
      const existing = await getAffiliateByEmail(env, lower);
      if (existing) return { ...existing, existed: true };
      if (attempt === 2) throw e;
    }
  }
}

export async function changeUsername(env, aff, wanted) {
  const u = normalizeUsername(wanted);
  if (aff.username_changed) return { error: 'You have already changed your username once. Ask us in Discord if you need another change.' };
  if (!validUsername(u)) return { error: 'Use 3 to 24 letters, numbers or underscores, with at least one letter.' };
  if (u === aff.username) return { error: 'That is already your username.' };
  if (await usernameTaken(env, u)) return { error: 'That username is taken. Try another.' };
  const now = nowIso();
  await env.DB.batch([
    env.DB.prepare('INSERT INTO usernames (username, affiliate_id, created_at) VALUES (?, ?, ?)').bind(u, aff.id, now),
    env.DB.prepare('UPDATE affiliates SET username = ?, username_changed = 1 WHERE id = ?').bind(u, aff.id),
  ]);
  return { ok: true, username: u };
}

export async function touch(env, affId) {
  await env.DB.prepare('UPDATE affiliates SET last_active_at = ? WHERE id = ?').bind(nowIso(), affId).run();
}

// Numbers for one affiliate. Conversions only count once Om approved them.
export async function affiliateStats(env, affId) {
  const q = (sql, ...b) => env.DB.prepare(sql).bind(...b).first();
  const [visits, uniq, downloads, approved, paid] = await Promise.all([
    q('SELECT COUNT(*) AS n FROM visits WHERE affiliate_id = ? AND is_bot = 0', affId),
    q("SELECT COUNT(DISTINCT COALESCE(visitor_id, id)) AS n FROM visits WHERE affiliate_id = ? AND is_bot = 0", affId),
    q("SELECT COUNT(*) AS n FROM events WHERE affiliate_id = ? AND type = 'store_redirect'", affId),
    q("SELECT COUNT(*) AS n, COALESCE(SUM(commission_usd), 0) AS earned FROM conversions WHERE affiliate_id = ? AND status = 'approved'", affId),
    q('SELECT COALESCE(SUM(amount_usd), 0) AS paid FROM payouts WHERE affiliate_id = ?', affId),
  ]);
  const earned = round(approved.earned);
  const paidOut = round(paid.paid);
  const balance = round(earned - paidOut);
  return {
    visits: visits.n, uniqueVisitors: uniq.n, downloads: downloads.n,
    sales: approved.n, earned, paid: paidOut, balance, payable: balance >= MIN_PAYOUT_USD,
  };
}

const round = (n) => Math.round((Number(n) || 0) * 100) / 100;

export async function balanceOf(env, affId) {
  const a = await env.DB.prepare("SELECT COALESCE(SUM(commission_usd),0) AS e FROM conversions WHERE affiliate_id = ? AND status = 'approved'").bind(affId).first();
  const p = await env.DB.prepare('SELECT COALESCE(SUM(amount_usd),0) AS p FROM payouts WHERE affiliate_id = ?').bind(affId).first();
  return round(a.e - p.p);
}
