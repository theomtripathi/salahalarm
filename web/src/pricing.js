// Price tiers by visitor country (Cloudflare's request.cf.country).
//
// The iOS paywall charges $29.99/yr everywhere, and checkout data shows that
// price stops buyers in Saudi Arabia, Nigeria, Indonesia and India. On the web
// we can price per market, so each country maps to a tier, and each tier maps
// to its own pair of Dodo Payments products (see PRODUCTS in wrangler.toml).
//
// `display` prices are what the paywall shows when Dodo's checkout preview is
// unavailable. Keep them equal to the Dodo product prices.

// `weeklyOffer` is the discounted weekly plan shown when someone closes the
// paywall without buying. It is never listed on the paywall itself.
//
// Om's pricing (Oct 2026): $3.99/week and $29.99/year, half price for India and
// other lower-income countries. Dodo charges in the buyer's local currency.
const FULL = { weekly: { usd: 3.99 }, yearly: { usd: 29.99 }, weeklyOffer: { usd: 2.99 } };
export const TIERS = {
  // High-income markets
  t1: FULL,
  // Everything unlisted: same as t1 for now, kept separate so it can be tuned later
  t2: FULL,
  // Half price: the largest Android-only Muslim audiences
  t3: { weekly: { usd: 1.99 }, yearly: { usd: 14.99 }, weeklyOffer: { usd: 1.49 } },
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

// Plans on the paywall, in display order.
export const PLANS = ["yearly", "weekly"];
// Everything that can be checked out, including the exit offer.
export const CHECKOUT_PLANS = [...PLANS, "weeklyOffer"];

export function intervalFor(plan) {
  return plan === "yearly" ? "Year" : "Week";
}

// Products come from the PRODUCTS env var: {"t1":{"weekly":"pdt_..","yearly":"pdt_..","weeklyOffer":"pdt_.."},...}.
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
      weeklyEquivalent: plan === "yearly" ? Math.floor((usd / 52) * 100) / 100 : usd,
      trialDays: Number(trialDays[plan] || 0),
    };
  });
}

/** The exit offer as the paywall shows it, with the regular weekly price for the strike-through. */
export function displayOffer(tier) {
  const prices = TIERS[tier] || TIERS.t2;
  const [offer] = displayPlans(tier, { plans: ["weeklyOffer"] });
  return { ...offer, regularAmount: prices.weekly.usd, percentOff: Math.round((1 - prices.weeklyOffer.usd / prices.weekly.usd) * 100) };
}
