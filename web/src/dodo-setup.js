// Creates the SalahAlarm subscription products (yearly, weekly and the
// discounted weekly exit offer) for every price tier, plus the entitlement
// webhook. Used by scripts/dodo-setup.mjs and the one-time admin route.

import { TIERS, CHECKOUT_PLANS, intervalFor } from "./pricing.js";

const NAMES = { yearly: "Yearly", weekly: "Weekly", weeklyOffer: "Weekly, special offer" };

export const WEBHOOK_EVENTS = [
  "subscription.active", "subscription.renewed", "subscription.on_hold", "subscription.cancelled",
  "subscription.expired", "subscription.failed", "subscription.past_due", "subscription.paused",
  "subscription.unpaused", "subscription.updated", "subscription.plan_changed",
];

/** `call(method, path, body)` talks to the Dodo API; `log` reports progress. */
export async function setupDodo(call, { webhookUrl, log = () => {} } = {}) {
  const products = {};
  for (const [tier, plans] of Object.entries(TIERS)) {
    for (const plan of CHECKOUT_PLANS) {
      const { usd } = plans[plan];
      const interval = intervalFor(plan);
      const product = await call("POST", "/products", {
        name: `SalahAlarm Premium (${NAMES[plan]})`,
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
          subscription_period_count: plan === "yearly" ? 10 : 520,
          subscription_period_interval: interval,
          tax_inclusive: true,
        },
      });
      (products[tier] ||= {})[plan] = product.product_id;
      log(`created ${tier} ${plan} $${usd} → ${product.product_id}`);
    }
  }

  let webhook = null;
  if (webhookUrl) {
    const hook = await call("POST", "/webhooks", {
      url: webhookUrl,
      description: "SalahAlarm Android entitlements",
      filter_types: WEBHOOK_EVENTS,
    });
    let secret = hook.secret || null;
    if (!secret) {
      try {
        secret = (await call("GET", `/webhooks/${encodeURIComponent(hook.id)}/secret`)).secret || null;
      } catch (err) {
        log(`could not read the webhook secret: ${err.message}`);
      }
    }
    webhook = { id: hook.id, secret };
    log(`webhook ${hook.id} created`);
  }
  return { products, webhook };
}
