// Sessions for affiliates (email magic links) and for Om's admin dashboard (password).
import { sha256, randomToken, nowIso, getCookie, cookie } from './util.js';

export const AFF_COOKIE = 'aff_s';
export const ADMIN_COOKIE = 'aff_admin';
const AFF_DAYS = 90;
const ADMIN_DAYS = 14;

export async function createSession(env, { affiliateId = null, role }) {
  const token = randomToken(32);
  const days = role === 'admin' ? ADMIN_DAYS : AFF_DAYS;
  const expires = new Date(Date.now() + days * 864e5).toISOString();
  await env.DB.prepare('INSERT INTO sessions (token_hash, affiliate_id, role, expires_at) VALUES (?, ?, ?, ?)')
    .bind(await sha256(token), affiliateId, role, expires).run();
  return cookie(role === 'admin' ? ADMIN_COOKIE : AFF_COOKIE, token, { maxAge: days * 86400 });
}

export async function readSession(env, request, role) {
  const token = getCookie(request, role === 'admin' ? ADMIN_COOKIE : AFF_COOKIE);
  if (!token) return null;
  const row = await env.DB.prepare('SELECT * FROM sessions WHERE token_hash = ? AND role = ?')
    .bind(await sha256(token), role).first();
  if (!row || row.expires_at < nowIso()) return null;
  return row;
}

export async function endSession(env, request, role) {
  const token = getCookie(request, role === 'admin' ? ADMIN_COOKIE : AFF_COOKIE);
  if (token) await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(await sha256(token)).run();
  return cookie(role === 'admin' ? ADMIN_COOKIE : AFF_COOKIE, '', { maxAge: 0 });
}

export async function createLoginToken(env, affiliateId) {
  const token = randomToken(32);
  const expires = new Date(Date.now() + 30 * 60e3).toISOString();
  await env.DB.prepare('INSERT INTO login_tokens (token_hash, affiliate_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
    .bind(await sha256(token), affiliateId, expires, nowIso()).run();
  return { token, expires };
}

export async function useLoginToken(env, token) {
  const hash = await sha256(token || '');
  const row = await env.DB.prepare('SELECT * FROM login_tokens WHERE token_hash = ?').bind(hash).first();
  if (!row || row.used_at || row.expires_at < nowIso()) return null;
  await env.DB.prepare('UPDATE login_tokens SET used_at = ? WHERE token_hash = ?').bind(nowIso(), hash).run();
  return row.affiliate_id;
}

export async function recentLoginTokens(env, affiliateId) {
  const since = new Date(Date.now() - 10 * 60e3).toISOString();
  const r = await env.DB.prepare('SELECT COUNT(*) AS n FROM login_tokens WHERE affiliate_id = ? AND created_at > ?')
    .bind(affiliateId, since).first();
  return r?.n || 0;
}

// Admin password: PBKDF2-SHA256, stored as "pbkdf2$<iterations>$<salt b64>$<hash b64>".
// The hash lives in ADMIN_PASSWORD_HASH (wrangler var) or, once Om changes it, in settings.admin_password_hash.
export async function hashPassword(password, saltB64, iterations = 100000) {
  const salt = saltB64 ? Uint8Array.from(atob(saltB64), (c) => c.charCodeAt(0)) : crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations }, key, 256);
  const b64 = (a) => btoa(String.fromCharCode(...new Uint8Array(a)));
  return `pbkdf2$${iterations}$${b64(salt)}$${b64(bits)}`;
}

export async function checkPassword(password, stored) {
  if (!stored || !password) return false;
  const [scheme, iter, salt, hash] = stored.split('$');
  if (scheme !== 'pbkdf2') return false;
  const again = await hashPassword(password, salt, Number(iter));
  const a = again.split('$')[3];
  if (a.length !== hash.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ hash.charCodeAt(i);
  return diff === 0;
}

export async function adminPasswordHash(env) {
  const row = await env.DB.prepare("SELECT value FROM settings WHERE key = 'admin_password_hash'").first();
  return row?.value || env.ADMIN_PASSWORD_HASH || null;
}
