// salahalarm.com Android funnel Worker.
//
//   /get                     bio-link page: App Store or Android (static)
//   /android/                web onboarding → Google sign-in → paywall (static)
//   /android/welcome/        after checkout: confirm payment, download APK, install guide (static)
//   /android/install/        install guide on its own, for reinstalls (static)
//   /api/config              geo, price tier, prayer times, public client config
//   /api/profile             save onboarding answers to users/{uid} (same fields as iOS)
//   /api/checkout            create a Dodo Payments checkout session
//   /api/trial               start the no-card free trial (last exit offer, once per account)
//   /api/entitlement         is this Firebase user premium? (confirms a fresh checkout too)
//   /api/portal              Dodo customer portal link (cancel, change card)
//   /api/webhooks/dodo       Dodo Payments webhooks → entitlements/{uid}
//   /api/app-login           one-time code that signs the installed app into this account
//   /api/app-login/redeem    the app trades that code for a Firebase custom token
//   /api/android/latest      newest APK version, for the in-app update prompt
//   /api/android/download    a 30-minute APK link, only for accounts with an active plan or trial
//   /api/admin/dodo-setup    one-time: create the Dodo products + webhook (Cloudflare token holders only)
//   /api/admin/dodo-products create a fresh set of products at the current TIERS prices (same auth)
//   /api/admin/dodo-discount create a Dodo discount from DISCOUNTS in pricing.js (same auth)
//   /api/admin/prices        what each country is charged (Cloudflare token holders only)
//   /download/salahalarm.apk the APK, streamed from R2; needs a link from /api/android/download

import { verifyIdToken, bearer, AuthError } from "./auth.js";
import { Firestore, parseServiceAccount, customToken } from "./firestore.js";
import { Dodo, DodoError, verifyWebhook } from "./dodo.js";
import { setupDodo } from "./dodo-setup.js";
import { tierFor, productFor, parseProducts, displayPlans, displayOffer, CHECKOUT_PLANS, discountFor, discounted, DISCOUNTS } from "./pricing.js";
import { entitlementFromSubscription, shouldReplace, isActive, publicEntitlement } from "./entitlement.js";
import { scheduleFor } from "./prayer.js";
import { sanitizeProfile } from "./profile.js";

const APK_KEY = "salahalarm-latest.apk";
const APK_META_KEY = "latest.json";
const LANGS = ["en", "ar", "tr", "id", "ur"];

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    try {
      if (request.method === "OPTIONS") return cors(new Response(null, { status: 204 }), request, env);
      const res = await route(request, env, ctx, url);
      return url.pathname.startsWith("/api/") ? cors(res, request, env) : res;
    } catch (err) {
      const status = err instanceof AuthError ? err.status : err.status && err.status < 500 ? 400 : 500;
      if (status >= 500) console.error(err.stack || err);
      const res = json({ error: err instanceof DodoError ? "payment provider error" : err.message }, status);
      return url.pathname.startsWith("/api/") ? cors(res, request, env) : res;
    }
  },
};

async function route(request, env, ctx, url) {
  const { pathname } = url;
  const method = request.method;

  if (pathname === "/api/config" && method === "GET") return config(request, env, ctx);
  if (pathname === "/api/profile" && method === "POST") return saveProfile(request, env);
  if (pathname === "/api/checkout" && method === "POST") return checkout(request, env, ctx, url);
  if (pathname === "/api/trial" && method === "POST") return startTrial(request, env, ctx);
  if (pathname === "/api/entitlement" && method === "GET") return entitlement(request, env, url);
  if (pathname === "/api/portal" && method === "POST") return portal(request, env);
  if (pathname === "/api/webhooks/dodo" && method === "POST") return webhook(request, env, ctx);
  if (pathname === "/api/app-login" && method === "POST") return createAppLogin(request, env);
  if (pathname === "/api/app-login/redeem" && method === "POST") return redeemAppLogin(request, env, ctx);
  if (pathname === "/api/android/latest" && method === "GET") return latest(env);
  if (pathname === "/api/android/download" && method === "POST") return downloadLink(request, env);
  if (pathname === "/api/admin/dodo-setup" && method === "POST") return adminDodoSetup(request, env, url);
  if (pathname === "/api/admin/dodo-products" && method === "POST") return adminDodoProducts(request, env);
  if (pathname === "/api/admin/dodo-discount" && method === "POST") return adminDodoDiscount(request, env);
  if (pathname === "/api/admin/prices" && method === "GET") return adminPrices(request, env, ctx, url);
  if (pathname === "/download/salahalarm.apk" && (method === "GET" || method === "HEAD")) return download(request, env, ctx);
  if (pathname.startsWith("/api/")) return json({ error: "not found" }, 404);

  if (pathname === "/get") return Response.redirect(`${url.origin}/get/${url.search}`, 301);
  if (pathname === "/android") return Response.redirect(`${url.origin}/android/${url.search}`, 301);
  if (env.ASSETS) return env.ASSETS.fetch(request);
  return new Response("not found", { status: 404 });
}

// ---- helpers -------------------------------------------------------------

function json(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...headers },
  });
}

function cors(res, request, env) {
  const origin = request.headers.get("origin");
  const allowed = (env.ALLOWED_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
  if (origin && allowed.includes(origin)) {
    const headers = new Headers(res.headers);
    headers.set("access-control-allow-origin", origin);
    headers.set("access-control-allow-headers", "authorization, content-type");
    headers.set("access-control-allow-methods", "GET, POST, OPTIONS");
    headers.set("vary", "origin");
    return new Response(res.body, { status: res.status, headers });
  }
  return res;
}

function geo(request) {
  const cf = request.cf || {};
  return {
    country: (cf.country || request.headers.get("cf-ipcountry") || "").toUpperCase() || null,
    city: cf.city || null,
    region: cf.region || null,
    timezone: cf.timezone || null,
    latitude: cf.latitude ? Number(cf.latitude) : null,
    longitude: cf.longitude ? Number(cf.longitude) : null,
  };
}

async function user(request, env) {
  return verifyIdToken(bearer(request), env.FIREBASE_PROJECT_ID);
}

function firestore(env) {
  const serviceAccount = parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT);
  if (!serviceAccount) throw Object.assign(new Error("FIREBASE_SERVICE_ACCOUNT is not set"), { status: 503 });
  return new Firestore({ projectId: env.FIREBASE_PROJECT_ID, serviceAccount });
}

function dodo(env) {
  return new Dodo({ apiKey: env.DODO_PAYMENTS_API_KEY, environment: env.DODO_ENVIRONMENT || "test_mode" });
}

// Length of the no-card trial offered after both paywall exits.
function freeTrialDays(env) {
  const days = Number(env.FREE_TRIAL_DAYS || 7);
  return Number.isFinite(days) && days > 0 ? Math.min(days, 30) : 7;
}

function trialDays(env) {
  try {
    return JSON.parse(env.TRIAL_DAYS || "{}");
  } catch {
    return {};
  }
}

function capture(env, ctx, event, distinctId, properties) {
  if (!env.POSTHOG_KEY) return;
  ctx.waitUntil(
    fetch(`${env.POSTHOG_HOST || "https://us.i.posthog.com"}/capture/`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ api_key: env.POSTHOG_KEY, event, distinct_id: distinctId, properties }),
    }).catch(() => {}),
  );
}

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

// ---- /api/config -----------------------------------------------------------

async function config(request, env, ctx) {
  const g = geo(request);
  const tier = tierFor(g.country);
  const { plans, offer } = await localPrices(env, ctx, tier, g.country);
  // A discount link (?discount=CODE): the price after the code, for the paywall to show.
  const d = discountFor(new URL(request.url).searchParams.get("discount"));
  const target = d && plans.find((p) => p.plan === d.plan);
  const discount = target ? { code: d.code, plan: d.plan, percentOff: d.percentOff, cycles: d.cycles, currency: target.currency, amount: discounted(target.amount, d) } : null;
  const schedule = g.latitude != null ? scheduleFor({ ...g, now: new Date() }) : null;
  const lang = preferredLang(request.headers.get("accept-language"), g.country);
  return json({
    geo: { country: g.country, city: g.city, timezone: g.timezone, latitude: g.latitude, longitude: g.longitude },
    tier,
    plans,
    offer,
    discount,
    freeTrialDays: freeTrialDays(env),
    schedule,
    lang,
    firebase: {
      apiKey: env.FIREBASE_API_KEY,
      authDomain: env.FIREBASE_AUTH_DOMAIN || `${env.FIREBASE_PROJECT_ID}.firebaseapp.com`,
      projectId: env.FIREBASE_PROJECT_ID,
    },
    posthog: env.POSTHOG_KEY ? { key: env.POSTHOG_KEY, host: env.POSTHOG_HOST || "https://us.i.posthog.com" } : null,
    appStoreUrl: env.APP_STORE_URL,
    checkoutEnabled: Boolean(env.DODO_PAYMENTS_API_KEY),
  });
}

export function preferredLang(acceptLanguage, country) {
  const first = String(acceptLanguage || "").split(",")[0].trim().split(/[-_;]/)[0].toLowerCase();
  if (LANGS.includes(first)) return first;
  if (first === "in") return "id";
  if (first === "en" || !first) return "en";
  const byCountry = { ID: "id", TR: "tr", PK: "ur", SA: "ar", AE: "ar", EG: "ar", QA: "ar", KW: "ar", JO: "ar", MA: "ar", DZ: "ar", IQ: "ar", OM: "ar", BH: "ar", YE: "ar", LY: "ar", TN: "ar", SD: "ar", SY: "ar", LB: "ar", PS: "ar" };
  return byCountry[String(country || "").toUpperCase()] || "en";
}

// Ask Dodo what this country would actually pay, in local currency when adaptive
// pricing is on. Cached per country for six hours; falls back to USD list prices.
async function localPrices(env, ctx, tier, country) {
  const regular = displayOffer(tier, country);
  const fallback = { plans: displayPlans(tier, { trialDays: trialDays(env), country }), offer: regular };
  if (!env.DODO_PAYMENTS_API_KEY || env.PRICE_PREVIEW === "off" || !country) return fallback;
  const products = parseProducts(env.PRODUCTS);
  const cache = typeof caches !== "undefined" ? caches.default : null;
  const cacheKey = new Request(`https://cache.salahalarm.internal/prices/v4/${tier}/${country}/${env.DODO_ENVIRONMENT || "test_mode"}`);
  if (cache) {
    const hit = await cache.match(cacheKey);
    if (hit) return hit.json();
  }
  try {
    const client = dodo(env);
    const [plans, [offerPlan]] = await Promise.all([fallback.plans, [fallback.offer]].map((list) => Promise.all(
      list.map(async (p) => {
        const product = productFor(products, tier, p.plan, country);
        if (!product) return p;
        const preview = await client.previewCheckout({
          product_cart: [{ product_id: product.productId, quantity: 1 }],
          billing_address: { country },
        });
        const line = preview.product_cart?.[0];
        const currency = line?.currency || preview.currency;
        const recurring = line?.discounted_price ?? preview.recurring_breakup?.total_amount;
        if (!currency || typeof recurring !== "number") return p;
        const amount = recurring / minorUnits(currency);
        return {
          ...p,
          currency,
          amount,
          weeklyEquivalent: p.plan === "yearly" ? amount / 52 : amount,
          trialDays: preview.trial_period_days ?? p.trialDays,
        };
      }),
    )));
    // The strike-through price is the regular weekly plan in the same currency.
    const weekly = plans.find((p) => p.plan === "weekly");
    const offer = weekly && weekly.currency === offerPlan.currency
      ? { ...offerPlan, regularAmount: weekly.amount, percentOff: Math.round((1 - offerPlan.amount / weekly.amount) * 100) }
      : { ...regular, ...offerPlan, regularAmount: offerPlan.currency === regular.currency ? regular.regularAmount : null };
    const result = { plans, offer };
    if (cache) {
      ctx.waitUntil(cache.put(cacheKey, new Response(JSON.stringify(result), { headers: { "cache-control": "max-age=21600" } })));
    }
    return result;
  } catch (err) {
    console.warn("price preview failed", err.message);
    return fallback;
  }
}

const ZERO_DECIMAL = new Set(["JPY", "KRW", "VND", "CLP", "PYG", "UGX", "XAF", "XOF", "RWF", "KMF", "GNF", "DJF", "BIF", "MGA", "VUV", "XPF"]);
const THREE_DECIMAL = new Set(["BHD", "KWD", "OMR", "JOD", "TND", "LYD", "IQD"]);
function minorUnits(currency) {
  const c = String(currency).toUpperCase();
  if (ZERO_DECIMAL.has(c)) return 1;
  if (THREE_DECIMAL.has(c)) return 1000;
  return 100;
}

// ---- /api/profile ----------------------------------------------------------

async function saveProfile(request, env) {
  const u = await user(request, env);
  const body = await readJson(request);
  const { profile, plan } = sanitizeProfile(body);
  const db = firestore(env);
  await db.merge(`users/${u.uid}`, {
    userId: u.uid,
    email: u.email,
    ...(u.name && { name: u.name }),
    onboardingProfile: profile,
    onboardingDerivedPlan: plan,
    onboardingLastScreen: profile.lastCompletedScreen,
    onboardingCompletedAt: new Date(),
    onboardingPlatform: "android_web",
  });
  return json({ ok: true });
}

// ---- /api/checkout ---------------------------------------------------------

async function checkout(request, env, ctx, url) {
  const u = await user(request, env);
  const body = await readJson(request);
  const plan = CHECKOUT_PLANS.includes(body.plan) ? body.plan : "yearly";
  const g = geo(request);
  const tier = tierFor(g.country);
  const product = productFor(parseProducts(env.PRODUCTS), tier, plan, g.country);
  if (!product) return json({ error: "checkout is not configured yet" }, 503);

  const db = firestore(env);
  const existing = await db.get(`entitlements/${u.uid}`);
  // Someone on the free trial can still buy; a paying subscriber can't buy twice.
  if (isActive(existing) && existing.provider !== "trial") return json({ alreadyActive: true, entitlement: publicEntitlement(existing) });

  const origin = env.PUBLIC_ORIGIN || url.origin;
  const lang = LANGS.includes(body.lang) ? body.lang : "en";
  const ref = String(body.ref || "").slice(0, 60);
  const days = Number(trialDays(env)[plan] || 0);
  const discount = discountFor(body.discount, plan);
  const session = await dodo(env).createCheckout({
    product_cart: [{ product_id: product.productId, quantity: 1 }],
    customer: { email: u.email || undefined, name: String(body.name || u.name || "").slice(0, 80) || undefined },
    ...(g.country && { billing_address: { country: g.country } }),
    return_url: `${origin}/android/welcome/?plan=${plan}`,
    // Backing out of checkout counts as closing the paywall: show the next exit offer.
    cancel_url: `${origin}/android/?resume=paywall&exit=${plan === "weeklyOffer" ? "trial" : "offer"}`,
    metadata: { uid: u.uid, plan, tier: product.tier, country: g.country || "", ref, lang, source: "android_web", ...(discount && { discount: discount.code }) },
    ...(discount && { discount_codes: [discount.code] }),
    customization: { force_language: lang, theme: "light", show_order_details: true },
    feature_flags: { redirect_immediately: true, allow_discount_code: true, allow_customer_editing_email: !u.email },
    ...(days > 0 && { subscription_data: { trial_period_days: days } }),
  });

  await db.merge(`users/${u.uid}`, { lastWebCheckout: { sessionId: session.session_id, plan, tier: product.tier, at: new Date() } });
  capture(env, ctx, "web_checkout_session_created", u.uid, { plan, tier: product.tier, country: g.country, ref, lang, discount: discount?.code || null });
  return json({ checkoutUrl: session.checkout_url, sessionId: session.session_id });
}

// ---- /api/trial --------------------------------------------------------------

async function startTrial(request, env, ctx) {
  const u = await user(request, env);
  const db = firestore(env);
  const existing = await db.get(`entitlements/${u.uid}`);
  if (isActive(existing)) return json({ entitlement: publicEntitlement(existing), alreadyActive: true });
  const profile = await db.get(`users/${u.uid}`);
  // One trial per account, and none for someone who has already paid before.
  if (profile?.freeTrialStartedAt || existing?.provider === "dodo") return json({ error: "trial already used" }, 409);

  const now = Date.now();
  const days = freeTrialDays(env);
  const ent = trialEntitlement(u, days, now);
  await db.merge(`entitlements/${u.uid}`, ent);
  await db.merge(`users/${u.uid}`, { freeTrialStartedAt: new Date(now), freeTrialDays: days });
  capture(env, ctx, "web_free_trial_started", u.uid, { days, country: geo(request).country });
  return json({ entitlement: publicEntitlement(ent, now) });
}

export function trialEntitlement(u, days, now = Date.now()) {
  const iso = new Date(now).toISOString();
  return {
    active: true,
    provider: "trial",
    status: "trial",
    plan: "trial",
    subscriptionId: null,
    customerId: null,
    email: u.email ? String(u.email).toLowerCase() : null,
    trialDays: days,
    currentPeriodEnd: null,
    cancelAtPeriodEnd: false,
    accessUntil: new Date(now + days * 24 * 60 * 60 * 1000).toISOString(),
    lastEventAt: iso,
    updatedAt: iso,
  };
}

// ---- /api/admin/dodo-setup ---------------------------------------------------
//
// The Dodo key lives only in this Worker's secrets, so product setup runs here.
// The caller must hold a Cloudflare API token for this Worker's own account:
// whoever has one can redeploy the Worker anyway, so this grants nothing new.

// Admin routes accept the deploy's Cloudflare API token, so only GitHub Actions can call them.
async function isAdmin(request, env) {
  const token = bearer(request);
  const account = env.ADMIN_CF_ACCOUNT;
  if (!token || !account) return false;
  const check = await fetch(`https://api.cloudflare.com/client/v4/accounts/${account}/tokens/verify`, {
    headers: { authorization: `Bearer ${token}` },
  });
  const verified = check.ok ? await check.json().catch(() => null) : null;
  return Boolean(verified?.success && verified.result?.status === "active");
}

async function adminPrices(request, env, ctx, url) {
  if (!(await isAdmin(request, env))) return json({ error: "unauthorized" }, 401);
  const countries = (url.searchParams.get("countries") || "US,AE,SA,QA,KW,GB,TR,MY,IN,PK,ID,BD,EG,NG")
    .split(",").map((c) => c.trim().toUpperCase()).filter(Boolean).slice(0, 40);
  const rows = await Promise.all(countries.map(async (country) => {
    const tier = tierFor(country);
    const { plans, offer } = await localPrices(env, ctx, tier, country);
    return { country, tier, plans: plans.map((p) => ({ plan: p.plan, currency: p.currency, amount: p.amount })), offer: { currency: offer.currency, amount: offer.amount } };
  }));
  return json({ rows });
}

// New prices need new products; existing subscribers keep the ones they bought.
async function adminDodoProducts(request, env) {
  if (!(await isAdmin(request, env))) return json({ error: "unauthorized" }, 401);
  const { scope } = await readJson(request);
  const client = dodo(env);
  const log = [];
  try {
    const { products } = await setupDodo((method, path, payload) => client.request(method, path, payload), {
      log: (line) => log.push(line),
      scope: scope === "local" ? "local" : "tiers",
    });
    return json({ products, log });
  } catch (err) {
    return json({ error: err.message, detail: err.body ?? null, log }, 502);
  }
}

// Creates (once) the Dodo discount for a DISCOUNTS entry, limited to that plan's products.
async function adminDodoDiscount(request, env) {
  if (!(await isAdmin(request, env))) return json({ error: "unauthorized" }, 401);
  const { code } = await readJson(request);
  const d = discountFor(code);
  if (!d) return json({ error: `unknown code; add it to DISCOUNTS first (${Object.keys(DISCOUNTS).join(", ")})` }, 400);
  const products = parseProducts(env.PRODUCTS);
  const restricted = [...new Set(Object.values(products).map((p) => p?.[d.plan]).filter(Boolean))];
  try {
    const created = await dodo(env).request("POST", "/discounts", {
      type: "percentage",
      amount: d.bp,
      code: d.code,
      name: `${d.code}: ${d.percentOff}% off the first ${d.cycles === 1 ? "payment" : `${d.cycles} payments`} (${d.plan})`,
      restricted_to: restricted,
      subscription_cycles: d.cycles,
      per_customer_usage_limit: 1,
      metadata: { app: "salahalarm-android" },
    });
    return json({ discount: { id: created.discount_id, code: created.code, amount: created.amount, restricted_to: restricted.length } });
  } catch (err) {
    return json({ error: err.message, detail: err.body ?? null }, 502);
  }
}

async function adminDodoSetup(request, env, url) {
  if (!(await isAdmin(request, env))) return json({ error: "unauthorized" }, 401);

  if (Object.keys(parseProducts(env.PRODUCTS)).length) return json({ error: "products already configured" }, 409);
  const body = await readJson(request);
  const environment = body.environment === "live_mode" ? "live_mode" : "test_mode";
  const client = new Dodo({ apiKey: env.DODO_PAYMENTS_API_KEY, environment });
  const log = [];
  try {
    const result = await setupDodo((method, path, payload) => client.request(method, path, payload), {
      webhookUrl: `${env.PUBLIC_ORIGIN || url.origin}/api/webhooks/dodo`,
      log: (line) => log.push(line),
    });
    return json({ environment, ...result, log });
  } catch (err) {
    // Products created before the failure are in the log.
    return json({ error: err.message, detail: err.body ?? null, log }, 502);
  }
}

// ---- /api/entitlement --------------------------------------------------------

async function entitlement(request, env, url) {
  const u = await user(request, env);
  const db = firestore(env);
  let ent = await db.get(`entitlements/${u.uid}`);

  // Right after checkout the webhook may still be in flight: confirm with Dodo directly.
  if (!isActive(ent) && env.DODO_PAYMENTS_API_KEY) {
    const confirmed = await confirmCheckout(env, db, u, url.searchParams);
    if (confirmed) ent = confirmed;
  }

  // A purchase whose webhook had no uid (e.g. paid from a payment link) is parked by email.
  if (!isActive(ent) && u.email && u.emailVerified) {
    const pending = await db.get(`pendingEntitlements/${u.email}`);
    if (isActive(pending)) {
      ent = { ...pending, uid: u.uid, claimedAt: new Date().toISOString() };
      await db.merge(`entitlements/${u.uid}`, ent);
      await db.delete(`pendingEntitlements/${u.email}`);
    }
  }
  return json({ entitlement: publicEntitlement(ent) });
}

async function confirmCheckout(env, db, u, params) {
  const client = dodo(env);
  let subscriptionId = params.get("subscription_id");
  try {
    if (!subscriptionId) {
      let paymentId = params.get("payment_id");
      const sessionId = params.get("session_id") || (await db.get(`users/${u.uid}`))?.lastWebCheckout?.sessionId;
      if (!paymentId && sessionId) {
        const session = await client.getCheckout(sessionId);
        paymentId = session.payment_status === "succeeded" ? session.payment_id : null;
      }
      if (paymentId) {
        const payment = await client.getPayment(paymentId);
        if (payment.status === "succeeded") subscriptionId = payment.subscription_id || payment.subscription_ids?.[0] || null;
      }
    }
    if (!subscriptionId) return null;
    const sub = await client.getSubscription(subscriptionId);
    const owner = sub.metadata?.uid;
    const emailMatches = u.email && u.emailVerified && String(sub.customer?.email || "").toLowerCase() === u.email;
    if (owner !== u.uid && !(owner == null && emailMatches)) return null;
    const ent = entitlementFromSubscription(sub);
    if (!ent.active) return null;
    const current = await db.get(`entitlements/${u.uid}`);
    if (!shouldReplace(current, ent)) return current;
    await db.merge(`entitlements/${u.uid}`, { ...ent, uid: u.uid });
    return ent;
  } catch (err) {
    if (err instanceof DodoError && err.status === 404) return null;
    throw err;
  }
}

// ---- /api/app-login ----------------------------------------------------------
// The welcome page hands the freshly installed app a one-time code in an
// intent link, so people who just paid land in the app already signed in.

const APP_LOGIN_TTL_MS = 30 * 60 * 1000;

async function createAppLogin(request, env) {
  const u = await user(request, env);
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  const code = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
  const expiresAt = new Date(Date.now() + APP_LOGIN_TTL_MS).toISOString();
  await firestore(env).merge(`appLoginCodes/${code}`, { uid: u.uid, email: u.email || null, expiresAt, createdAt: new Date() });
  return json({ code, expiresAt });
}

async function redeemAppLogin(request, env, ctx) {
  const { code } = await readJson(request);
  if (typeof code !== "string" || !/^[0-9a-f]{48}$/.test(code)) return json({ error: "invalid code" }, 400);
  const db = firestore(env);
  const doc = await db.get(`appLoginCodes/${code}`);
  if (!doc) return json({ error: "code not found or already used" }, 404);
  await db.delete(`appLoginCodes/${code}`);
  if (!doc.uid || Date.parse(doc.expiresAt) < Date.now()) return json({ error: "code expired" }, 410);
  const token = await customToken(parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT), doc.uid);
  capture(env, ctx, "android_app_login_link_used", doc.uid, {});
  return json({ token });
}

// ---- /api/portal -----------------------------------------------------------

async function portal(request, env) {
  const u = await user(request, env);
  const ent = await firestore(env).get(`entitlements/${u.uid}`);
  if (!ent?.customerId) return json({ error: "no web subscription on this account" }, 404);
  const session = await dodo(env).customerPortal(ent.customerId);
  return json({ url: session.link });
}

// ---- /api/webhooks/dodo ----------------------------------------------------

async function webhook(request, env, ctx) {
  const body = await request.text();
  try {
    await verifyWebhook(env.DODO_WEBHOOK_SECRET, request.headers, body);
  } catch (err) {
    return json({ error: err.message }, 401);
  }
  const event = JSON.parse(body);
  const result = await handleEvent(env, firestore(env), event);
  if ((result.uid || result.email) && !result.skipped) {
    const who = result.uid || result.email;
    // is_subscribed and email on the person drive the "didn't pay" email workflow.
    const $set = { is_subscribed: Boolean(result.active), web_plan: result.plan || null, ...(result.email && { email: result.email }) };
    const props = { status: result.status, plan: result.plan, country: result.country, ref: result.ref, tier: result.tier, $set };
    capture(env, ctx, `web_${event.type.replace(/\./g, "_")}`, who, props);
    // Same event name as iOS, so cross-platform funnels and workflows can stop on it.
    if (event.type === "subscription.active") capture(env, ctx, "purchase_completed", who, { ...props, platform: "android_web" });
  }
  return json({ ok: true, ...result });
}

export async function handleEvent(env, db, event) {
  const type = String(event.type || "");
  if (!type.startsWith("subscription.")) return { ignored: type };
  const sub = event.data || {};
  if (!sub.subscription_id) return { ignored: "no subscription id" };
  const ent = entitlementFromSubscription(sub, { eventAt: event.timestamp });
  const uid = sub.metadata?.uid || null;
  if (uid) {
    const current = await db.get(`entitlements/${uid}`);
    if (!shouldReplace(current, ent)) return { uid, skipped: "older event" };
    await db.merge(`entitlements/${uid}`, { ...ent, uid });
    return { uid, email: ent.email, active: ent.active, status: ent.status, plan: ent.plan, country: ent.country, ref: ent.ref, tier: ent.tier };
  }
  if (ent.email) {
    const current = await db.get(`pendingEntitlements/${ent.email}`);
    if (shouldReplace(current, ent)) await db.merge(`pendingEntitlements/${ent.email}`, ent);
    return { email: ent.email, active: ent.active, status: ent.status, pending: true };
  }
  return { ignored: "no uid or email" };
}

// ---- APK -------------------------------------------------------------------

async function latest(env) {
  let meta = null;
  if (env.APKS) {
    const obj = await env.APKS.get(APK_META_KEY);
    if (obj) meta = await obj.json();
  }
  meta ||= {
    versionCode: Number(env.APK_VERSION_CODE || 0),
    versionName: env.APK_VERSION_NAME || null,
  };
  return json({ ...meta, url: "/download/salahalarm.apk" }, 200, { "cache-control": "public, max-age=300" });
}

// The APK is only for paying (or trialling) accounts. The site and the app ask
// /api/android/download for a signed link that works for 30 minutes.
const DOWNLOAD_TTL_SECONDS = 30 * 60;

async function downloadKey(env) {
  const secret = env.DOWNLOAD_SECRET || env.FIREBASE_SERVICE_ACCOUNT;
  if (!secret) throw Object.assign(new Error("download signing is not configured"), { status: 503 });
  const material = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`apk-download:${secret}`));
  return crypto.subtle.importKey("raw", material, { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}

function b64url(bytes) {
  return btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function signDownload(env, uid, now = Date.now()) {
  const exp = Math.floor(now / 1000) + DOWNLOAD_TTL_SECONDS;
  const payload = `${b64url(new TextEncoder().encode(uid))}.${exp}`;
  const sig = await crypto.subtle.sign("HMAC", await downloadKey(env), new TextEncoder().encode(payload));
  return `${payload}.${b64url(sig)}`;
}

export async function verifyDownload(env, token, now = Date.now()) {
  const [uid64, exp, sig] = String(token || "").split(".");
  if (!uid64 || !exp || !sig || Number(exp) * 1000 < now) return false;
  const expected = await crypto.subtle.sign("HMAC", await downloadKey(env), new TextEncoder().encode(`${uid64}.${exp}`));
  const a = b64url(expected);
  if (a.length !== sig.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ sig.charCodeAt(i);
  return diff === 0;
}

async function downloadLink(request, env) {
  const u = await user(request, env);
  const ent = await firestore(env).get(`entitlements/${u.uid}`);
  if (!isActive(ent)) return json({ error: "no active plan", paywall: "/android/?resume=paywall" }, 402);
  let size = null;
  if (env.APKS) size = (await env.APKS.head(APK_KEY))?.size ?? null;
  return json({ url: `/download/salahalarm.apk?t=${await signDownload(env, u.uid)}`, size });
}

async function download(request, env, ctx) {
  if (!(await verifyDownload(env, new URL(request.url).searchParams.get("t")))) {
    return Response.redirect(new URL("/android/install/", request.url).href, 302);
  }
  if (!env.APKS) return new Response("APK storage is not configured", { status: 503 });
  const obj = request.method === "HEAD" ? await env.APKS.head(APK_KEY) : await env.APKS.get(APK_KEY);
  if (!obj) return new Response("The Android app is being prepared. Please try again in a few minutes.", { status: 404 });
  const ua = request.headers.get("user-agent") || "";
  capture(env, ctx, "apk_downloaded", request.headers.get("cf-connecting-ip") || "anon", {
    country: request.cf?.country || null,
    android: /android/i.test(ua),
    in_app_browser: /instagram|tiktok|musical_ly|bytedance|fban|fbav/i.test(ua),
    $process_person_profile: false,
  });
  const headers = new Headers({
    "content-type": "application/vnd.android.package-archive",
    "content-disposition": 'attachment; filename="SalahAlarm.apk"',
    "cache-control": "private, no-store",
    "x-content-type-options": "nosniff",
  });
  if (obj.size != null) headers.set("content-length", String(obj.size));
  if (obj.httpEtag) headers.set("etag", obj.httpEtag);
  return new Response(request.method === "HEAD" ? null : obj.body, { headers });
}
