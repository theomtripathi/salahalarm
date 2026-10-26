// Creates the SalahAlarm subscription products (yearly, weekly and the
// discounted weekly exit offer) for every price tier, plus the entitlement
// webhook. Used by scripts/dodo-setup.mjs and the one-time admin route.

import { TIERS, LOCAL, CHECKOUT_PLANS, intervalFor } from "./pricing.js";

const NAMES = { yearly: "Yearly", weekly: "Weekly", weeklyOffer: "Weekly, special offer" };

export const WEBHOOK_EVENTS = [
  "subscription.active", "subscription.renewed", "subscription.on_hold", "subscription.cancelled",
  "subscription.expired", "subscription.failed", "subscription.past_due", "subscription.paused",
  "subscription.unpaused", "subscription.updated", "subscription.plan_changed",
];

/**
 * `call(method, path, body)` talks to the Dodo API; `log` reports progress.
 * Tiers with the same prices share one set of products. `scope: "local"` creates
 * only the local-currency products (keyed by country) and no webhook.
 */
export async function setupDodo(call, { webhookUrl, log = () => {}, scope = "tiers" } = {}) {
  const product = (meta, plan, currency, amount) => call("POST", "/products", {
    name: `SalahAlarm Premium (${NAMES[plan]})`,
    description: "Prayer alarms, mat scan, prayer lock, Quran, Qibla and streaks for Android.",
    tax_category: "saas",
    metadata: { ...meta, plan, app: "salahalarm-android" },
    price: {
      type: "recurring_price",
      currency,
      price: Math.round(amount * 100),
      discount: 0,
      purchasing_power_parity: false,
      payment_frequency_count: 1,
      payment_frequency_interval: intervalFor(plan),
      subscription_period_count: plan === "yearly" ? 10 : 520,
      subscription_period_interval: intervalFor(plan),
      tax_inclusive: true,
    },
  });

  const products = {};
  if (scope === "local") {
    for (const [country, prices] of Object.entries(LOCAL)) {
      for (const plan of CHECKOUT_PLANS) {
        const created = await product({ tier: "t3", country }, plan, prices.currency, prices[plan]);
        (products[country] ||= {})[plan] = created.product_id;
        log(`created ${country} ${plan} ${prices.currency} ${prices[plan]} → ${created.product_id}`);
      }
    }
    return { products, webhook: null };
  }

  const byPrices = new Map();
  for (const [tier, plans] of Object.entries(TIERS)) {
    const same = byPrices.get(JSON.stringify(plans));
    if (same) {
      products[tier] = { ...products[same] };
      log(`${tier} shares ${same}'s products`);
      continue;
    }
    byPrices.set(JSON.stringify(plans), tier);
    for (const plan of CHECKOUT_PLANS) {
      const { usd } = plans[plan];
      const created = await product({ tier }, plan, "USD", usd);
      (products[tier] ||= {})[plan] = created.product_id;
      log(`created ${tier} ${plan} $${usd} → ${created.product_id}`);
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
