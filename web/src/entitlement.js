// Turns Dodo subscription state into the entitlement the Android app reads.
//
// Stored at Firestore entitlements/{uid}. The app treats the user as premium
// while `accessUntil` is in the future, so alarms keep working offline and a
// late renewal webhook does not lock anyone out.

const DAY = 24 * 60 * 60 * 1000;
export const RENEWAL_GRACE_DAYS = 2;
export const PAST_DUE_GRACE_DAYS = 3;
export const DEFAULT_FREE_TRIAL_DAYS = 7;

export function planFromSubscription(sub) {
  const interval = String(sub.payment_frequency_interval || sub.subscription_period_interval || "").toLowerCase();
  if (interval === "year") return "yearly";
  if (interval === "month") return "monthly";
  if (interval === "week") return "weekly";
  return sub.metadata?.plan || null;
}

function addDays(iso, days) {
  const t = Date.parse(iso);
  return Number.isFinite(t) ? new Date(t + days * DAY).toISOString() : null;
}

export function accessUntilFor(sub, now = Date.now()) {
  const nowIso = new Date(now).toISOString();
  switch (sub.status) {
    case "active":
      return addDays(sub.next_billing_date, RENEWAL_GRACE_DAYS) || addDays(nowIso, 31);
    case "past_due":
      return addDays(sub.next_billing_date, PAST_DUE_GRACE_DAYS) || nowIso;
    case "cancelled": {
      // A scheduled cancellation keeps access until the paid period ends.
      const end = sub.expires_at || (sub.cancel_at_next_billing_date ? sub.next_billing_date : null);
      return end && Date.parse(end) > now ? end : nowIso;
    }
    default:
      // pending, on_hold, paused, failed, expired
      return nowIso;
  }
}

export function entitlementFromSubscription(sub, { eventAt, now = Date.now() } = {}) {
  const accessUntil = accessUntilFor(sub, now);
  return {
    active: Date.parse(accessUntil) > now,
    provider: "dodo",
    status: sub.status,
    plan: planFromSubscription(sub),
    productId: sub.product_id || null,
    subscriptionId: sub.subscription_id,
    customerId: sub.customer?.customer_id || null,
    email: sub.customer?.email ? String(sub.customer.email).toLowerCase() : null,
    currency: sub.currency || null,
    amount: typeof sub.recurring_pre_tax_amount === "number" ? sub.recurring_pre_tax_amount : null,
    currentPeriodEnd: sub.next_billing_date || null,
    cancelAtPeriodEnd: Boolean(sub.cancel_at_next_billing_date),
    trialDays: sub.trial_period_days || 0,
    accessUntil,
    tier: sub.metadata?.tier || null,
    country: sub.metadata?.country || sub.billing?.country || null,
    ref: sub.metadata?.ref || null,
    lastEventAt: eventAt || new Date(now).toISOString(),
    updatedAt: new Date(now).toISOString(),
  };
}

/** The no-card free trial started from the paywall's last screen (see /api/trial). */
export function trialEntitlement({ uid, email, days, country = null, ref = null, now = Date.now() }) {
  const start = new Date(now).toISOString();
  return {
    uid,
    active: true,
    provider: "trial",
    status: "trialing",
    plan: "trial",
    email: email ? String(email).toLowerCase() : null,
    trialDays: days,
    trialStartedAt: start,
    accessUntil: new Date(now + days * DAY).toISOString(),
    country,
    ref,
    lastEventAt: start,
    updatedAt: start,
  };
}

/** True when `next` should replace `current` (ignores out-of-order webhooks for the same subscription). */
export function shouldReplace(current, next) {
  if (!current) return true;
  // A real subscription always replaces the free trial.
  if (current.provider === "trial" && next.provider !== "trial") return true;
  if (current.subscriptionId && next.subscriptionId && current.subscriptionId !== next.subscriptionId) {
    // A different subscription only replaces an inactive one, or one that ends sooner.
    if (!isActive(current)) return true;
    return Date.parse(next.accessUntil) > Date.parse(current.accessUntil);
  }
  return !current.lastEventAt || Date.parse(next.lastEventAt) >= Date.parse(current.lastEventAt);
}

export function isActive(ent, now = Date.now()) {
  return Boolean(ent && ent.accessUntil && Date.parse(ent.accessUntil) > now);
}

/** The subset of an entitlement sent to clients. */
export function publicEntitlement(ent, now = Date.now()) {
  if (!ent) return { active: false };
  const active = isActive(ent, now);
  const trial = ent.provider === "trial";
  return {
    active,
    status: trial && !active ? "trial_expired" : ent.status,
    trial,
    plan: ent.plan,
    accessUntil: ent.accessUntil,
    currentPeriodEnd: ent.currentPeriodEnd,
    cancelAtPeriodEnd: ent.cancelAtPeriodEnd,
    provider: ent.provider,
    email: ent.email,
    manageable: Boolean(ent.customerId),
  };
}
