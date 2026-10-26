// The in-app funnel and tracking-link clicks, from PostHog (project 572656).
// Needs POSTHOG_PERSONAL_API_KEY with "query:read". The phc_ project token
// used by the app can only send events, not read them.

const HOST = process.env.POSTHOG_HOST || 'https://us.posthog.com';
const PROJECT = process.env.POSTHOG_PROJECT_ID || '572656';

export async function hogql(query, key, fetchImpl = fetch) {
  const res = await fetchImpl(`${HOST}/api/projects/${PROJECT}/query/`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: { kind: 'HogQLQuery', query }, name: 'salahalarm-daily' }),
  });
  if (!res.ok) throw new Error(`posthog ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const j = await res.json();
  return j.results.map((row) => Object.fromEntries(j.columns.map((c, i) => [c, row[i]])));
}

// Test users are excluded through the project's internal cohort (509939) and
// the app's own internal_test_session flag.
// 8a9276eb… is Om's test iPhone (four yearly test purchases in Sweden, Oct 7–12).
const NOT_TEST = `person_id NOT IN COHORT 509939 AND coalesce(toString(properties.internal_test_session), '') != 'true' AND toString(person_id) != '8a9276eb-000a-5f50-abb8-ccb8e0bb5271'`;

export const QUERIES = {
  // One row per day for the last 15 days: the whole funnel, by unique people.
  daily: `
    SELECT toString(toDate(timestamp)) AS day,
      uniqIf(person_id, event = 'app_installed') AS installs,
      uniqIf(person_id, event = 'onboarding_started') AS onboarding_started,
      uniqIf(person_id, event = 'onboarding_completed') AS onboarding_completed,
      uniqIf(person_id, event = 'signup_completed') AS signup_completed,
      uniqIf(person_id, event = 'paywall_viewed') AS paywall_viewed,
      uniqIf(person_id, event = 'purchase_initiated') AS buy_tapped,
      uniqIf(person_id, event = 'purchase_cancelled' OR (event = 'purchase_failed' AND toString(properties.error_reason) ILIKE '%cancel%')) AS sheet_cancelled,
      uniqIf(person_id, event = 'purchase_failed' AND NOT toString(properties.error_reason) ILIKE '%cancel%') AS purchase_errors,
      uniqIf(person_id, event = 'purchase_completed') AS purchased,
      uniqIf(person_id, event = 'win_back_modal_shown') AS final_offer_shown,
      uniqIf(person_id, event = 'win_back_offer_accepted') AS final_offer_accepted,
      uniqIf(person_id, event = 'link_clicked') AS link_clicks
    FROM events
    WHERE timestamp >= today() - 15 AND ${NOT_TEST}
    GROUP BY day ORDER BY day`,
  // Onboarding screens: people per screen, this week vs last week.
  screens: `
    SELECT toString(properties.screen_name) AS screen, min(toInt(properties.screen_index)) AS idx,
      uniqIf(person_id, timestamp >= today() - 7) AS this_week,
      uniqIf(person_id, timestamp < today() - 7) AS last_week
    FROM events
    WHERE event = 'onboarding_screen_viewed' AND timestamp >= today() - 14 AND ${NOT_TEST}
    GROUP BY screen ORDER BY idx`,
  // Tracking-link clicks per account and video, last 7 days.
  links: `
    SELECT toString(properties.account) AS account, toString(properties.format) AS format,
      toString(properties.video) AS video, count() AS clicks,
      countIf(timestamp >= today() - 1 AND timestamp < today()) AS clicks_yesterday
    FROM events
    WHERE event = 'link_clicked' AND timestamp >= today() - 7 AND toString(properties.is_bot) != 'true'
    GROUP BY account, format, video ORDER BY clicks DESC`,
  // Android web funnel (salahalarm.com/get): this week and the week before, by unique people.
  android: `
    SELECT if(timestamp >= today() - 7, 'this', 'prev') AS period,
      uniqIf(person_id, event = 'bio_page_viewed') AS bio_views,
      uniqIf(person_id, event = 'bio_option_tapped' AND toString(properties.option) = 'android') AS tapped_android,
      uniqIf(person_id, event = 'bio_option_tapped' AND toString(properties.option) = 'ios') AS tapped_ios,
      uniqIf(person_id, event = 'web_onboarding_started') AS onboarding_started,
      uniqIf(person_id, event = 'web_paywall_viewed') AS paywall_viewed,
      uniqIf(person_id, event = 'web_exit_offer_viewed') AS exit_offer_viewed,
      uniqIf(person_id, event = 'web_free_trial_started') AS trials,
      uniqIf(person_id, event = 'web_checkout_started') AS checkout_started,
      uniqIf(person_id, event = 'web_subscription_active') AS paid,
      uniqIf(person_id, event IN ('apk_download_tapped', 'apk_download_auto_started')) AS apk_taps,
      countIf(event = 'apk_downloaded') AS apk_downloads,
      uniqIf(person_id, event = 'android_app_first_open') AS app_first_open
    FROM events
    WHERE timestamp >= today() - 14 AND timestamp < today()
      AND (startsWith(event, 'web_') OR startsWith(event, 'bio_') OR startsWith(event, 'apk_') OR startsWith(event, 'android_'))
    GROUP BY period ORDER BY period DESC`,
  // Why people leave the paywall, when they tell us.
  exitReasons: `
    SELECT toString(properties.reason) AS reason, count() AS n
    FROM events
    WHERE event = 'paywall_exit_reason_submitted' AND timestamp >= today() - 14 AND ${NOT_TEST}
    GROUP BY reason ORDER BY n DESC`,
  countries: `
    SELECT properties.$geoip_country_code AS country,
      uniqIf(person_id, event = 'app_installed') AS installs,
      uniqIf(person_id, event = 'paywall_viewed') AS paywall_viewed,
      uniqIf(person_id, event = 'purchase_initiated') AS buy_tapped,
      uniqIf(person_id, event = 'purchase_completed') AS purchased
    FROM events WHERE timestamp >= today() - 7 AND ${NOT_TEST}
    GROUP BY country ORDER BY installs DESC LIMIT 12`,
};

export async function collect(key, { fetchImpl = fetch } = {}) {
  const out = {}, errors = [];
  for (const [name, q] of Object.entries(QUERIES)) {
    try { out[name] = await hogql(q, key, fetchImpl); }
    catch (e) { errors.push(`posthog ${name}: ${e.message}`); }
  }
  return { ...out, errors };
}
