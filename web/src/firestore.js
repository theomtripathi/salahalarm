// Minimal Firestore REST client authenticated as a Firebase service account.
// The service account JSON lives in the FIREBASE_SERVICE_ACCOUNT secret.

import { b64urlDecode } from "./auth.js";

const SCOPE = "https://www.googleapis.com/auth/datastore";
let cachedToken = null; // { token, expires, email }

function b64url(bytes) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToPkcs8(pem) {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return b64urlDecode(body.replace(/\+/g, "-").replace(/\//g, "_"));
}

export function parseServiceAccount(raw) {
  if (!raw) return null;
  const sa = typeof raw === "string" ? JSON.parse(raw) : raw;
  if (!sa.client_email || !sa.private_key) throw new Error("service account JSON needs client_email and private_key");
  return sa;
}

export async function accessToken(sa, { fetch: fetchImpl = fetch, now = Date.now() } = {}) {
  if (cachedToken && cachedToken.email === sa.client_email && cachedToken.expires > now + 60_000) {
    return cachedToken.token;
  }
  const iat = Math.floor(now / 1000);
  const enc = (obj) => b64url(new TextEncoder().encode(JSON.stringify(obj)));
  const unsigned = `${enc({ alg: "RS256", typ: "JWT" })}.${enc({
    iss: sa.client_email,
    scope: SCOPE,
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp: iat + 3600,
  })}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)));
  const res = await fetchImpl("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${b64url(sig)}`,
    }),
  });
  if (!res.ok) throw new Error(`service account token failed (${res.status}): ${await res.text()}`);
  const json = await res.json();
  cachedToken = { token: json.access_token, expires: now + (json.expires_in || 3600) * 1000, email: sa.client_email };
  return cachedToken.token;
}

// ---- value encoding -------------------------------------------------------

export function toValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === "string") return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  if (typeof v === "object") return { mapValue: { fields: toFields(v) } };
  return { stringValue: String(v) };
}

export function toFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined) fields[k] = toValue(v);
  }
  return fields;
}

export function fromValue(v) {
  if (!v) return null;
  if ("nullValue" in v) return null;
  if ("booleanValue" in v) return v.booleanValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("stringValue" in v) return v.stringValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("arrayValue" in v) return (v.arrayValue.values || []).map(fromValue);
  if ("mapValue" in v) return fromFields(v.mapValue.fields || {});
  return null;
}

export function fromFields(fields = {}) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) out[k] = fromValue(v);
  return out;
}

// ---- documents -------------------------------------------------------------

export class Firestore {
  constructor({ projectId, serviceAccount, fetch: fetchImpl }) {
    this.projectId = projectId;
    this.sa = serviceAccount;
    this.fetch = fetchImpl || ((...args) => fetch(...args));
    this.base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  }

  async headers() {
    const token = await accessToken(this.sa, { fetch: this.fetch });
    return { authorization: `Bearer ${token}`, "content-type": "application/json" };
  }

  docUrl(path) {
    return `${this.base}/${path.split("/").map(encodeURIComponent).join("/")}`;
  }

  async get(path) {
    const res = await this.fetch(this.docUrl(path), { headers: await this.headers() });
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`firestore get ${path} failed (${res.status}): ${await res.text()}`);
    const doc = await res.json();
    return fromFields(doc.fields);
  }

  // Merge-writes the given top-level fields, like setData(..., merge: true).
  async merge(path, data) {
    const params = new URLSearchParams();
    for (const key of Object.keys(data)) params.append("updateMask.fieldPaths", `\`${key.replace(/`/g, "\\`")}\``);
    const res = await this.fetch(`${this.docUrl(path)}?${params}`, {
      method: "PATCH",
      headers: await this.headers(),
      body: JSON.stringify({ fields: toFields(data) }),
    });
    if (!res.ok) throw new Error(`firestore write ${path} failed (${res.status}): ${await res.text()}`);
    return fromFields((await res.json()).fields);
  }

  async delete(path) {
    const res = await this.fetch(this.docUrl(path), { method: "DELETE", headers: await this.headers() });
    if (!res.ok && res.status !== 404) throw new Error(`firestore delete ${path} failed (${res.status})`);
  }
}

export function resetTokenCache() {
  cachedToken = null;
}
