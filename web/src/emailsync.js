// Copies sign-in emails from Firebase Auth onto PostHog persons, so the lifecycle
// emails in PostHog Workflows can reach iPhone users. The iOS app identifies people
// in PostHog by their Firebase uid but never sends an email; the web funnel does.
//
// Runs on the Worker's cron (see wrangler.toml):
//   every 15 minutes  people who signed up or signed in within the last 45 minutes
//   Sundays 03:17 UTC everyone (Cloudflare wants SUN, not 0) (backfill, and catches anything the short runs missed)
//
// It only sends `$set` events, which no workflow triggers on, so a run never starts
// or restarts an email sequence. It never removes or overwrites an email with nothing.

import { signServiceJwt } from "./firestore.js";

export const FULL_SYNC_CRON = "17 3 * * SUN";
const RECENT_MS = 45 * 60 * 1000;
const PAGE = 1000;
const POSTHOG_BATCH = 500;

export async function identityToken(sa, { fetch: fetchImpl = fetch, now = Date.now() } = {}) {
  const iat = Math.floor(now / 1000);
  const assertion = await signServiceJwt(sa, {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/identitytoolkit https://www.googleapis.com/auth/cloud-platform",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp: iat + 3600,
  });
  const res = await fetchImpl("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  if (!res.ok) throw new Error(`identity token failed (${res.status}): ${await res.text()}`);
  return (await res.json()).access_token;
}

/** Every Firebase Auth account, page by page (accounts:batchGet). */
export async function* listAuthUsers(projectId, token, { fetch: fetchImpl = fetch } = {}) {
  let pageToken = "";
  do {
    const url = new URL(`https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:batchGet`);
    url.searchParams.set("maxResults", String(PAGE));
    if (pageToken) url.searchParams.set("nextPageToken", pageToken);
    const res = await fetchImpl(url, { headers: { authorization: `Bearer ${token}` } });
    if (!res.ok) throw new Error(`listing Firebase users failed (${res.status}): ${await res.text()}`);
    const body = await res.json();
    for (const u of body.users || []) yield u;
    pageToken = body.nextPageToken || "";
  } while (pageToken);
}

/** The email to store for one account, or null. Falls back to a provider's email. */
export function emailOf(user) {
  const direct = typeof user.email === "string" ? user.email.trim() : "";
  if (direct.includes("@")) return direct.toLowerCase();
  for (const p of user.providerUserInfo || []) {
    const e = typeof p.email === "string" ? p.email.trim() : "";
    if (e.includes("@")) return e.toLowerCase();
  }
  return null;
}

/** Signed up or signed in since `since` (ms). Firebase gives both as ms strings. */
export function isRecent(user, since) {
  return Number(user.createdAt || 0) >= since || Number(user.lastLoginAt || 0) >= since;
}

export function setEvent(user, email, now) {
  return {
    event: "$set",
    distinct_id: user.localId,
    timestamp: new Date(now).toISOString(),
    properties: {
      $set: { email },
      $set_once: { email_source: "firebase_auth" },
      $lib: "salahalarm-email-sync",
      // Backend enrichment: do not make dormant people look active.
      $update_person_last_seen_at: false,
    },
  };
}

async function sendBatch(env, events, fetchImpl) {
  const res = await fetchImpl(`${env.POSTHOG_HOST || "https://us.i.posthog.com"}/batch/`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ api_key: env.POSTHOG_KEY, batch: events }),
  });
  if (!res.ok) throw new Error(`PostHog batch failed (${res.status}): ${await res.text()}`);
}

/**
 * One sync run. `full` sends everyone with an email; otherwise only accounts
 * created or signed in within the last 45 minutes.
 */
export async function syncEmails(env, sa, { full = false, now = Date.now(), fetch: fetchImpl = fetch } = {}) {
  if (!env.POSTHOG_KEY) throw new Error("POSTHOG_KEY is not set");
  const token = await identityToken(sa, { fetch: fetchImpl, now });
  const since = now - RECENT_MS;
  let seen = 0;
  let sent = 0;
  let pending = [];
  for await (const user of listAuthUsers(env.FIREBASE_PROJECT_ID, token, { fetch: fetchImpl })) {
    seen++;
    if (user.disabled || !user.localId) continue;
    if (!full && !isRecent(user, since)) continue;
    const email = emailOf(user);
    if (!email) continue;
    pending.push(setEvent(user, email, now));
    if (pending.length >= POSTHOG_BATCH) {
      await sendBatch(env, pending, fetchImpl);
      sent += pending.length;
      pending = [];
    }
  }
  if (pending.length) {
    await sendBatch(env, pending, fetchImpl);
    sent += pending.length;
  }
  return { full, seen, sent };
}
