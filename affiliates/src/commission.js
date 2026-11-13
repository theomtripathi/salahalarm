// Internal commission rules. Public copy only ever says "50% of revenue".
// Yearly plan: the first month's revenue = 1/12 of the yearly price (e.g. $40/yr -> $3.33).
// Weekly plan: 50% of the first week only; renewals earn nothing.
// Lifetime (not sold right now): 50% of the one-time price. Assumption, change here if Om decides otherwise.
// Amounts are the customer's gross charge in USD. Non-USD charges are converted
// with FX_TO_USD and flagged in the admin dashboard.

export const MIN_PAYOUT_USD = 100;

// Rough rates, only used when a charge arrives in another currency without amount_usd.
export const FX_TO_USD = {
  USD: 1, EUR: 1.08, GBP: 1.27, CAD: 0.73, AUD: 0.66, AED: 0.2723, SAR: 0.2666, QAR: 0.2747, KWD: 3.25,
  OMR: 2.6, BHD: 2.65, TRY: 0.029, MYR: 0.22, INR: 0.012, PKR: 0.0036, IDR: 0.000063, BDT: 0.0084,
  EGP: 0.02, NGN: 0.00065, MAD: 0.1, SGD: 0.75, ZAR: 0.055,
};

export const round2 = (n) => Math.round(n * 100) / 100;

export function toUsd(amount, currency, amountUsd) {
  const n = Number(amount) || 0;
  if (amountUsd !== undefined && amountUsd !== null && amountUsd !== '' && Number.isFinite(Number(amountUsd))) {
    return { usd: round2(Number(amountUsd)), estimated: false };
  }
  const cur = String(currency || 'USD').toUpperCase();
  if (cur === 'USD') return { usd: round2(n), estimated: false };
  const rate = FX_TO_USD[cur];
  return { usd: rate ? round2(n * rate) : round2(n), estimated: true };
}

export function intervalOf({ interval, product_id, plan } = {}) {
  const s = `${interval || ''} ${product_id || ''} ${plan || ''}`.toLowerCase();
  if (/lifetime|forever|one[-_ ]?time/.test(s)) return 'lifetime';
  if (/week|p1w/.test(s)) return 'week';
  if (/year|annual|p1y/.test(s)) return 'year';
  if (/month|p1m/.test(s)) return 'month';
  return 'unknown';
}

// kind: first | renewal. Returns { commission, rule }.
export function commissionFor({ interval, kind, amountUsd }) {
  const a = Math.max(0, Number(amountUsd) || 0);
  if (kind !== 'first') return { commission: 0, rule: 'renewal: no commission (first payment only)' };
  switch (interval) {
    case 'year': return { commission: round2(a / 12), rule: 'yearly: first month = price / 12' };
    case 'week': return { commission: round2(a * 0.5), rule: 'weekly: 50% of the first week' };
    case 'month': return { commission: round2(a * 0.5), rule: 'monthly (not sold): 50% of the first month' };
    case 'lifetime': return { commission: round2(a * 0.5), rule: 'lifetime (assumed): 50% of the price' };
    default: return { commission: round2(a * 0.5), rule: 'unknown plan: 50% of the first payment, check it' };
  }
}
