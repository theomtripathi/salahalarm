// Verifies Firebase Auth ID tokens inside a Worker (no Admin SDK).
// https://firebase.google.com/docs/auth/admin/verify-id-tokens#verify_id_tokens_using_a_third-party_jwt_library

const JWKS_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

let cachedKeys = null; // { keys: Map<kid, CryptoKey>, expires: ms }

export function b64urlDecode(input) {
  const s = input.replace(/-/g, "+").replace(/_/g, "/");
  const pad = s.length % 4 ? "=".repeat(4 - (s.length % 4)) : "";
  const bin = atob(s + pad);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function decodeJson(part) {
  return JSON.parse(new TextDecoder().decode(b64urlDecode(part)));
}

async function loadKeys(fetchImpl, now) {
  if (cachedKeys && cachedKeys.expires > now) return cachedKeys.keys;
  const res = await fetchImpl(JWKS_URL);
  if (!res.ok) throw new AuthError(`could not load Firebase signing keys (${res.status})`, 503);
  const { keys } = await res.json();
  const map = new Map();
  for (const jwk of keys) {
    const key = await crypto.subtle.importKey(
      "jwk",
      { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
    map.set(jwk.kid, key);
  }
  const maxAge = Number((res.headers.get("cache-control") || "").match(/max-age=(\d+)/)?.[1] || 3600);
  cachedKeys = { keys: map, expires: now + maxAge * 1000 };
  return map;
}

export class AuthError extends Error {
  constructor(message, status = 401) {
    super(message);
    this.status = status;
  }
}

export function resetKeyCache() {
  cachedKeys = null;
}

/**
 * Returns { uid, email, emailVerified, name, provider } for a valid token, or throws AuthError.
 * `options.fetch` and `options.now` exist for tests.
 */
export async function verifyIdToken(token, projectId, options = {}) {
  const fetchImpl = options.fetch || fetch;
  const now = options.now ?? Date.now();
  if (!token) throw new AuthError("missing token");
  const parts = token.split(".");
  if (parts.length !== 3) throw new AuthError("malformed token");

  let header, payload;
  try {
    header = decodeJson(parts[0]);
    payload = decodeJson(parts[1]);
  } catch {
    throw new AuthError("malformed token");
  }
  if (header.alg !== "RS256") throw new AuthError("unexpected algorithm");

  const keys = await loadKeys(fetchImpl, now);
  const key = keys.get(header.kid);
  if (!key) throw new AuthError("unknown signing key");

  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    b64urlDecode(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new AuthError("bad signature");

  const seconds = Math.floor(now / 1000);
  const skew = 300;
  if (payload.aud !== projectId) throw new AuthError("wrong audience");
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new AuthError("wrong issuer");
  if (!payload.sub || typeof payload.sub !== "string") throw new AuthError("missing subject");
  if (typeof payload.exp !== "number" || payload.exp + skew < seconds) throw new AuthError("token expired");
  if (typeof payload.iat !== "number" || payload.iat - skew > seconds) throw new AuthError("token issued in the future");

  return {
    uid: payload.sub,
    email: payload.email ? String(payload.email).toLowerCase() : null,
    emailVerified: Boolean(payload.email_verified),
    name: payload.name || null,
    provider: payload.firebase?.sign_in_provider || null,
  };
}

export function bearer(request) {
  const header = request.headers.get("authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}
