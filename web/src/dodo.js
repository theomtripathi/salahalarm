// Dodo Payments REST calls used by the Worker, plus Standard Webhooks
// signature verification (the scheme Dodo signs webhooks with).

const BASE = {
  live_mode: "https://live.dodopayments.com",
  test_mode: "https://test.dodopayments.com",
};

export class DodoError extends Error {
  constructor(message, status, body) {
    super(message);
    this.status = status;
    this.body = body;
  }
}

export class Dodo {
  constructor({ apiKey, environment = "test_mode", fetch: fetchImpl }) {
    if (!apiKey) throw new Error("DODO_PAYMENTS_API_KEY is not set");
    this.apiKey = apiKey;
    this.base = BASE[environment] || BASE.test_mode;
    this.fetch = fetchImpl || ((...args) => fetch(...args));
  }

  async request(method, path, body) {
    const res = await this.fetch(`${this.base}${path}`, {
      method,
      headers: { authorization: `Bearer ${this.apiKey}`, "content-type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = null;
    }
    if (!res.ok) throw new DodoError(`dodo ${method} ${path} failed (${res.status})`, res.status, json || text);
    return json;
  }

  createCheckout(body) {
    return this.request("POST", "/checkouts", body);
  }
  previewCheckout(body) {
    return this.request("POST", "/checkouts/preview", body);
  }
  getCheckout(id) {
    return this.request("GET", `/checkouts/${encodeURIComponent(id)}`);
  }
  getPayment(id) {
    return this.request("GET", `/payments/${encodeURIComponent(id)}`);
  }
  getSubscription(id) {
    return this.request("GET", `/subscriptions/${encodeURIComponent(id)}`);
  }
  customerPortal(customerId) {
    return this.request("POST", `/customers/${encodeURIComponent(customerId)}/customer-portal/session`);
  }
}

// ---- webhooks (https://www.standardwebhooks.com) ---------------------------

function base64ToBytes(b64) {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesToBase64(bytes) {
  let bin = "";
  for (const b of new Uint8Array(bytes)) bin += String.fromCharCode(b);
  return btoa(bin);
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function signWebhook(secret, id, timestamp, body) {
  const keyBytes = base64ToBytes(secret.startsWith("whsec_") ? secret.slice(6) : secret);
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${id}.${timestamp}.${body}`));
  return `v1,${bytesToBase64(sig)}`;
}

/** Throws unless the request carries a valid signature from the given secret. */
export async function verifyWebhook(secret, headers, body, { now = Date.now(), toleranceSeconds = 300 } = {}) {
  if (!secret) throw new Error("DODO_WEBHOOK_SECRET is not set");
  const id = headers.get("webhook-id");
  const timestamp = headers.get("webhook-timestamp");
  const signatures = headers.get("webhook-signature");
  if (!id || !timestamp || !signatures) throw new Error("missing webhook headers");
  const ts = Number(timestamp);
  if (!Number.isFinite(ts) || Math.abs(now / 1000 - ts) > toleranceSeconds) throw new Error("webhook timestamp outside tolerance");
  const expected = (await signWebhook(secret, id, timestamp, body)).split(",")[1];
  const ok = signatures.split(" ").some((part) => {
    const [version, sig] = part.split(",");
    return version === "v1" && sig && timingSafeEqual(sig, expected);
  });
  if (!ok) throw new Error("bad webhook signature");
  return { id, timestamp: ts };
}
