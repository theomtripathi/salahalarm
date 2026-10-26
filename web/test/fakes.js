// An in-memory stand-in for Google (JWKS, OAuth, Firestore REST) and Dodo Payments,
// installed as globalThis.fetch so the Worker runs unmodified.

import { generateKeyPairSync, createSign, randomUUID } from "node:crypto";
import { fromFields, toFields } from "../src/firestore.js";

export const PROJECT = "test-project";

const idKeys = generateKeyPairSync("rsa", { modulusLength: 2048 });
const saKeys = generateKeyPairSync("rsa", { modulusLength: 2048 });
const KID = "test-kid";

export const serviceAccount = {
  client_email: "worker@test-project.iam.gserviceaccount.com",
  private_key: saKeys.privateKey.export({ type: "pkcs8", format: "pem" }),
};

const b64url = (buf) => Buffer.from(buf).toString("base64url");

export function idToken({ uid = "user-1", email = "amina@example.com", verified = true, project = PROJECT, expOffset = 3600, kid = KID } = {}) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", kid, typ: "JWT" }));
  const payload = b64url(JSON.stringify({
    iss: `https://securetoken.google.com/${project}`,
    aud: project,
    sub: uid,
    iat: now - 10,
    exp: now + expOffset,
    email,
    email_verified: verified,
    name: "Amina",
    firebase: { sign_in_provider: "google.com" },
  }));
  const signer = createSign("RSA-SHA256");
  signer.update(`${header}.${payload}`);
  return `${header}.${payload}.${b64url(signer.sign(idKeys.privateKey))}`;
}

export function createBackend() {
  const docs = new Map(); // "collection/id" → plain object
  const dodo = {
    sessions: new Map(),
    payments: new Map(),
    subscriptions: new Map(),
    created: [],
    previewCurrency: null,
  };
  const calls = [];

  async function handle(url, init = {}) {
    const u = new URL(url);
    const method = (init.method || "GET").toUpperCase();
    calls.push(`${method} ${u.host}${u.pathname}`);
    const body = init.body && typeof init.body === "string" ? init.body : null;
    const reply = (data, status = 200, headers = {}) =>
      new Response(data == null ? null : JSON.stringify(data), { status, headers: { "content-type": "application/json", ...headers } });

    if (u.host === "www.googleapis.com" && u.pathname.includes("/jwk/securetoken")) {
      const jwk = idKeys.publicKey.export({ format: "jwk" });
      return reply({ keys: [{ ...jwk, kid: KID, alg: "RS256", use: "sig" }] }, 200, { "cache-control": "public, max-age=600" });
    }
    if (u.host === "oauth2.googleapis.com") return reply({ access_token: "sa-token", expires_in: 3600 });

    if (u.host === "firestore.googleapis.com") {
      if (init.headers?.authorization !== "Bearer sa-token") return reply({ error: "unauthenticated" }, 401);
      const path = decodeURIComponent(u.pathname.split("/documents/")[1]);
      if (method === "GET") {
        return docs.has(path) ? reply({ name: path, fields: toFields(docs.get(path)) }) : reply({ error: "not found" }, 404);
      }
      if (method === "PATCH") {
        const incoming = fromFields(JSON.parse(body).fields);
        const merged = { ...(docs.get(path) || {}), ...incoming };
        docs.set(path, merged);
        return reply({ name: path, fields: toFields(merged) });
      }
      if (method === "DELETE") {
        docs.delete(path);
        return reply({});
      }
    }

    if (u.host === "test.dodopayments.com") {
      if (init.headers?.authorization !== "Bearer dodo-key") return reply({ message: "unauthorized" }, 401);
      const parts = u.pathname.split("/").filter(Boolean);
      if (method === "POST" && u.pathname === "/checkouts") {
        const req = JSON.parse(body);
        const id = `cks_${randomUUID().slice(0, 8)}`;
        dodo.sessions.set(id, { id, req, payment_status: null, payment_id: null });
        dodo.created.push(req);
        return reply({ session_id: id, checkout_url: `https://test.checkout.dodopayments.com/session/${id}` });
      }
      if (method === "POST" && u.pathname === "/checkouts/preview") {
        if (!dodo.previewCurrency) return reply({ message: "preview disabled" }, 400);
        const { currency, amount } = dodo.previewCurrency;
        return reply({ currency, billing_country: "ID", total_price: amount, product_cart: [{ currency, discounted_price: amount }] });
      }
      if (method === "GET" && parts[0] === "checkouts") {
        const s = dodo.sessions.get(parts[1]);
        return s ? reply(s) : reply({ message: "not found" }, 404);
      }
      if (method === "GET" && parts[0] === "payments") {
        const p = dodo.payments.get(parts[1]);
        return p ? reply(p) : reply({ message: "not found" }, 404);
      }
      if (method === "GET" && parts[0] === "subscriptions") {
        const s = dodo.subscriptions.get(parts[1]);
        return s ? reply(s) : reply({ message: "not found" }, 404);
      }
      if (method === "POST" && parts[0] === "customers" && parts[2] === "customer-portal") {
        return reply({ link: `https://test.customer.dodopayments.com/${parts[1]}` });
      }
    }
    if (u.host.endsWith("posthog.com")) return reply({ status: 1 });
    return reply({ error: `unhandled ${method} ${url}` }, 599);
  }

  // Simulates a customer paying for a checkout session.
  function pay(sessionId, { status = "active", nextBilling = new Date(Date.now() + 365 * 864e5).toISOString() } = {}) {
    const session = dodo.sessions.get(sessionId);
    const paymentId = `pay_${sessionId}`;
    const subscriptionId = `sub_${sessionId}`;
    session.payment_status = "succeeded";
    session.payment_id = paymentId;
    const sub = {
      subscription_id: subscriptionId,
      status,
      product_id: session.req.product_cart[0].product_id,
      customer: { customer_id: "cus_1", email: session.req.customer?.email || "amina@example.com", name: "Amina" },
      metadata: session.req.metadata,
      next_billing_date: nextBilling,
      payment_frequency_interval: session.req.metadata.plan === "yearly" ? "Year" : "Week",
      currency: "USD",
      recurring_pre_tax_amount: 999,
      cancel_at_next_billing_date: false,
      trial_period_days: 0,
    };
    dodo.subscriptions.set(subscriptionId, sub);
    dodo.payments.set(paymentId, { payment_id: paymentId, status: "succeeded", subscription_id: subscriptionId, metadata: session.req.metadata });
    return sub;
  }

  return { docs, dodo, calls, fetch: handle, pay };
}

export function env(overrides = {}) {
  return {
    FIREBASE_PROJECT_ID: PROJECT,
    FIREBASE_API_KEY: "web-key",
    FIREBASE_SERVICE_ACCOUNT: JSON.stringify(serviceAccount),
    DODO_PAYMENTS_API_KEY: "dodo-key",
    DODO_ENVIRONMENT: "test_mode",
    DODO_WEBHOOK_SECRET: `whsec_${Buffer.from("super-secret-webhook-key").toString("base64")}`,
    PRODUCTS: JSON.stringify({
      t1: { weekly: "pdt_t1_w", yearly: "pdt_t1_y", weekly_offer: "pdt_t1_wo" },
      t2: { weekly: "pdt_t2_w", yearly: "pdt_t2_y", weekly_offer: "pdt_t2_wo" },
      t3: { weekly: "pdt_t3_w", yearly: "pdt_t3_y", weekly_offer: "pdt_t3_wo" },
    }),
    PUBLIC_ORIGIN: "https://salahalarm.com",
    PRICE_PREVIEW: "on",
    ...overrides,
  };
}

export const ctx = { waitUntil: () => {} };

export function request(path, { method = "GET", token, body, country = "ID", headers = {}, cf = {} } = {}) {
  const req = new Request(`https://salahalarm.com${path}`, {
    method,
    headers: {
      ...(token && { authorization: `Bearer ${token}` }),
      ...(body && { "content-type": "application/json" }),
      ...headers,
    },
    body: body ? (typeof body === "string" ? body : JSON.stringify(body)) : undefined,
  });
  Object.defineProperty(req, "cf", {
    value: { country, city: "Jakarta", timezone: "Asia/Jakarta", latitude: "-6.2088", longitude: "106.8456", ...cf },
  });
  return req;
}
