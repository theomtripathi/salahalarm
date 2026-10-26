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

// Where Dodo can charge in local currency, the half-price tier gets its own
// products priced in that currency, so buyers see ₹169, not $1.99. Rounded from
// the USD price at Oct 2026 exchange rates; change freely, then create new
// products (scope "local") and update PRODUCTS. Pakistan stays in USD: Dodo
// cannot charge PKR.
export const LOCAL = {
  IN: { currency: "INR", weekly: 169, yearly: 1249, weeklyOffer: 129 },
  ID: { currency: "IDR", weekly: 32900, yearly: 244900, weeklyOffer: 24900 },
  BD: { currency: "BDT", weekly: 239, yearly: 1799, weeklyOffer: 179 },
  EG: { currency: "EGP", weekly: 99, yearly: 749, weeklyOffer: 75 },
  NG: { currency: "NGN", weekly: 2999, yearly: 22999, weeklyOffer: 2299 },
};

function localFor(country) {
  return LOCAL[String(country || "").toUpperCase()] || null;
}

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

// Products come from the PRODUCTS env var: {"t1":{"weekly":"pdt_..","yearly":"pdt_..","weeklyOffer":"pdt_.."},...},
// plus local-currency products keyed by country ({"IN":{...}}), which win for that country.
// A missing tier falls back to t2, then t1, so a partial setup still sells.
export function productFor(products, tier, plan, country) {
  const c = String(country || "").toUpperCase();
  if (localFor(c) && products?.[c]?.[plan]) return { tier, productId: products[c][plan], local: c };
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
// `country` switches to the local-currency price where one is set.
export function displayPlans(tier, { trialDays = {}, plans = PLANS, country } = {}) {
  const prices = TIERS[tier] || TIERS.t2;
  const local = localFor(country);
  return plans.map((plan) => {
    const amount = local ? local[plan] : prices[plan].usd;
    return {
      plan,
      currency: local ? local.currency : "USD",
      amount,
      weeklyEquivalent: plan === "yearly" ? Math.floor((amount / 52) * 100) / 100 : amount,
      trialDays: Number(trialDays[plan] || 0),
    };
  });
}

/** The exit offer as the paywall shows it, with the regular weekly price for the strike-through. */
export function displayOffer(tier, country) {
  const [offer] = displayPlans(tier, { plans: ["weeklyOffer"], country });
  const [weekly] = displayPlans(tier, { plans: ["weekly"], country });
  return { ...offer, regularAmount: weekly.amount, percentOff: Math.round((1 - offer.amount / weekly.amount) * 100) };
}
