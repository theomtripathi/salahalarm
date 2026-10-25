// Creates the Dodo Payments subscription products for every price tier and
// prints the PRODUCTS value for wrangler.toml.
//
//   DODO_PAYMENTS_API_KEY=... DODO_ENVIRONMENT=test_mode node scripts/dodo-setup.mjs
//   add WEBHOOK_URL=https://salahalarm.com/api/webhooks/dodo to also register the webhook

import { TIERS } from "../src/pricing.js";

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
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status}: ${text}`);
  return JSON.parse(text);
}

const products = {};
for (const [tier, plans] of Object.entries(TIERS)) {
  for (const [plan, { usd }] of Object.entries(plans)) {
    const interval = plan === "yearly" ? "Year" : "Month";
    const product = await call("POST", "/products", {
      name: `SalahAlarm Premium (${plan === "yearly" ? "Yearly" : "Monthly"})`,
      description: "Prayer alarms, mat scan, prayer lock, Quran, Qibla and streaks for Android.",
      tax_category: "saas",
      metadata: { tier, plan, app: "salahalarm-android" },
      price: {
        type: "recurring_price",
        currency: "USD",
        price: Math.round(usd * 100),
        discount: 0,
        purchasing_power_parity: false,
        payment_frequency_count: 1,
        payment_frequency_interval: interval,
        subscription_period_count: plan === "yearly" ? 10 : 120,
        subscription_period_interval: interval,
        tax_inclusive: true,
      },
    });
    (products[tier] ||= {})[plan] = product.product_id;
    console.log(`created ${tier} ${plan} $${usd} → ${product.product_id}`);
  }
}

if (process.env.WEBHOOK_URL) {
  const hook = await call("POST", "/webhooks", {
    url: process.env.WEBHOOK_URL,
    description: "SalahAlarm Android entitlements",
    filter_types: ["subscription.active", "subscription.renewed", "subscription.on_hold", "subscription.cancelled",
      "subscription.expired", "subscription.failed", "subscription.past_due", "subscription.paused",
      "subscription.unpaused", "subscription.updated", "subscription.plan_changed"],
  });
  console.log(`webhook ${hook.id} created; copy its signing secret from the Dodo dashboard into DODO_WEBHOOK_SECRET`);
}

console.log(`\nPRODUCTS = '${JSON.stringify(products)}'`);
