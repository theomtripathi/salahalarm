// Price tiers by visitor country (Cloudflare's request.cf.country).
//
// The iOS paywall charges $29.99/yr everywhere, and checkout data shows that
// price stops buyers in Saudi Arabia, Nigeria, Indonesia and India. On the web
// we can price per market, so each country maps to a tier, and each tier maps
// to its own pair of Dodo Payments products (see PRODUCTS in wrangler.toml).
//
// `display` prices are what the paywall shows when Dodo's checkout preview is
// unavailable. Keep them equal to the Dodo product prices.

//
// `weekly_offer` is the discounted weekly plan shown once to people who close
// the paywall without choosing a plan.

export const TIERS = {
  // High-income markets
  t1: { yearly: { usd: 29.99 }, weekly: { usd: 4.99 }, weekly_offer: { usd: 2.99 } },
  // Middle-income markets and the default for anything unlisted
  t2: { yearly: { usd: 17.99 }, weekly: { usd: 2.99 }, weekly_offer: { usd: 1.99 } },
  // Price-sensitive markets with the largest Android-only Muslim audiences
  t3: { yearly: { usd: 9.99 }, weekly: { usd: 1.99 }, weekly_offer: { usd: 0.99 } },
};

const T1 = [
  "US", "CA", "GB", "IE", "AU", "NZ", "DE", "FR", "NL", "BE", "LU", "AT", "CH", "SE", "NO", "DK",
  "FI", "IS", "IT", "ES", "PT", "JP", "KR", "SG", "HK", "IL", "AE", "QA", "KW",
];

const T3 = [
  // South and South-East Asia
  "IN", "PK", "BD", "LK", "NP", "AF", "ID", "PH", "MM", "KH", "LA", "VN",
  // Africa
  "NG", "GH", "KE", "TZ", "UG", "ET", "SN", "ML", "NE", "BF", "TD", "SO", "SD", "CM", "CI", "GN",
  "MR", "GM", "SL", "LR", "TG", "BJ", "MW", "MZ", "ZW", "ZM", "RW", "DJ", "KM", "ER", "SS",
  // North Africa and the Middle East
  "EG", "MA", "DZ", "TN", "LY", "JO", "LB", "SY", "IQ", "YE", "PS", "IR",
  // Central Asia
  "UZ", "TJ", "KG", "TM", "AZ",
];

const COUNTRY_TIER = new Map([
  ...T1.map((c) => [c, "t1"]),
  ...T3.map((c) => [c, "t3"]),
]);

export function tierFor(country) {
  return COUNTRY_TIER.get(String(country || "").toUpperCase()) || "t2";
}

// Plans on the paywall, in order. OFFER_PLAN is only sold from the "wait" screen.
export const PLANS = ["yearly", "weekly"];
export const OFFER_PLAN = "weekly_offer";
export const ALL_PLANS = [...PLANS, OFFER_PLAN];

/** Billing interval of a plan id: "Year" or "Week". */
export function intervalFor(plan) {
  return plan === "yearly" ? "Year" : "Week";
}

// Products come from the PRODUCTS env var: {"t1":{"monthly":"pdt_..","yearly":"pdt_.."},...}.
// A missing tier falls back to t2, then t1, so a partial setup still sells.
export function productFor(products, tier, plan) {
  for (const t of [tier, "t2", "t1"]) {
    const id = products?.[t]?.[plan];
    if (id) return { tier: t, productId: id };
  }
  return null;
}

export function parseProducts(raw) {
  if (!raw) return {};
  if (typeof raw === "object") return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

// Plans as the paywall renders them, before any local-currency preview.
export function displayPlans(tier, { trialDays = {}, plans = PLANS } = {}) {
  const prices = TIERS[tier] || TIERS.t2;
  return plans.map((plan) => {
    const usd = prices[plan].usd;
    return {
      plan,
      currency: "USD",
      amount: usd,
      weeklyEquivalent: weeklyEquivalent(plan, usd),
      trialDays: Number(trialDays[plan] || 0),
    };
  });
}

/** What a plan costs per week, rounded down to the cent, for "only $0.58/week". */
export function weeklyEquivalent(plan, amount) {
  return plan === "yearly" ? Math.floor((amount / 52) * 100) / 100 : amount;
}

/** How much the yearly plan saves against paying weekly for a year, in whole percent. */
export function yearlySavings(tier) {
  const prices = TIERS[tier] || TIERS.t2;
  return Math.round((1 - prices.yearly.usd / (prices.weekly.usd * 52)) * 100);
}
