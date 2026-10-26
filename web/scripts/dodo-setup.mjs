// Creates the Dodo Payments subscription products (yearly, weekly and the
// discounted weekly exit offer) for every price tier and prints the PRODUCTS
// value for wrangler.toml.
//
//   DODO_PAYMENTS_API_KEY=... DODO_ENVIRONMENT=test_mode node scripts/dodo-setup.mjs
//   add WEBHOOK_URL=https://salahalarm.com/api/webhooks/dodo to also register the webhook

import { setupDodo } from "../src/dodo-setup.js";

const key = process.env.DODO_PAYMENTS_API_KEY;
const base = process.env.DODO_ENVIRONMENT === "live_mode" ? "https://live.dodopayments.com" : "https://test.dodopayments.com";
if (!key) {
  console.error("Set DODO_PAYMENTS_API_KEY");
  process.exit(1);
}

async function call(method, path, body) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status}: ${text}`);
  return JSON.parse(text);
}

const { products, webhook } = await setupDodo(call, { webhookUrl: process.env.WEBHOOK_URL, log: console.log });
if (webhook && !webhook.secret) console.log("copy the webhook signing secret from the Dodo dashboard into DODO_WEBHOOK_SECRET");
console.log(`\nPRODUCTS = '${JSON.stringify(products)}'`);
