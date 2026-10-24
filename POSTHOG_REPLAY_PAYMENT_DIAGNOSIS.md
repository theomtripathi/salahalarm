# Session replay and purchase outcome diagnosis

Investigated 22 October 2026 in PostHog project 572656.

## Follow-up: 23 October 2026

See [PAYWALL_ANALYTICS.md](PAYWALL_ANALYTICS.md) for the schema-v3 implementation, detailed interpretation rules, QA evidence, and remaining release checks. Public introductory screens and input-free paywalls are now explicitly readable while personal screens/default masking and sandboxed payment-view protection remain enabled. The final `yearlydiscounted` product is loaded from the separate `yearly-discounted` offering, without replacing the current offering or fabricating a price. A real billing-period mismatch excludes a SKU and emits a product-configuration diagnostic.

Live internal Test Store QA confirmed separate `purchase_cancelled` and `purchase_failed` events with correlated attempt IDs; no real charge was made. Explicit purchase restrictions additionally have their own `purchase_not_allowed` event. The SDK classifier's ten regression cases pass. PostHog's US app/feature-flags partial outage was confirmed on its official status page during the new playback check; the new recording page returned a loading error, so readable server playback is not signed off solely from event/recording metadata. The Test Store's annual SKU was configured as monthly and its exact final product was not loaded; production App Store metadata was not independently inspected. The guide separates these external/configuration limits from implemented client fixes.

## What the live data shows

For the 30 days ending at this investigation, `purchase_failed` contains **116 events in 83 distinct sessions**. Every one has `error_reason = 'Purchase was cancelled'`. These are events and sessions, not 116 separate customers or verified card declines. This supersedes the earlier summary's mixed event/user counts.

The old app also emitted `purchase_declined` when a user left the paywall. That event does not establish a rejected payment. Historical event names are preserved; interpret them using their captured reason and the app version.

The read-only query used to verify the failure reasons was:

```sql
SELECT properties.error_reason AS error_reason,
       count() AS error_events,
       count(DISTINCT properties.$session_id) AS sessions,
       min(timestamp) AS first_seen,
       max(timestamp) AS last_seen
FROM events
WHERE timestamp >= now() - INTERVAL 30 DAY
  AND event = 'purchase_failed'
GROUP BY error_reason
ORDER BY error_events DESC
LIMIT 30
```

The inspected session `01a16327-bc2e-7517-90fd-047b6bc92c35` has mobile replay metadata and interaction events, but no playable opening frame. It used posthog-ios 3.69.8 and app 2.3, build 21.

## Why the frames were missing

SalahAlarm uses SwiftUI. Its configuration enabled session replay but omitted `sessionReplayConfig.screenshotMode`, whose default is false. The installed PostHog SDK explicitly returns without taking a snapshot for a SwiftUI hosting controller when screenshot mode is false. Touches, network telemetry and regular analytics events can still reach PostHog, so a recording row is not evidence that screen frames exist.

Project settings were checked through the connected PostHog API: recording enabled; no sampling restriction, minimum duration, event trigger or linked flag; retention 30 days. The native SDK's absent web-only recording diagnostic properties were treated as unknown, not as proof of blocked uploads.

## Implemented changes

- Enable SwiftUI screenshot recording and sample 100% of eligible sessions.
- Preserve automatic masking of text, images and sandboxed system views.
- Flush at five queued events or ten seconds, and flush after the app queues its final background events and purchase outcomes. Keep the SDK's persistent offline queue and retry behavior.
- Configure the SDK's network session to wait for connectivity, so an offline launch can obtain recording settings when a network path becomes available instead of immediately failing that initial request.
- Resume the existing recording on activation, subject to the project settings and SDK opt-out behavior.
- After recording settings finish loading, request a layout pass of the active app view so the SDK can capture a static first screen even if no user has tapped yet.
- Add `analytics_schema_version = 2`, `session_replay_mode = screenshot` and `session_replay_sample_rate = 1` to new events. `session_replay_status` and funnel events report `replay_capture_active`. This indicates capture is active; it does **not** claim delivery or playable frames.
- Classify explicit cancellations as `purchase_cancelled`, deferred approval as `purchase_pending`, and actual errors as `purchase_failed`. Retain normalized category, description and SDK error domain/code when available.
- Purchase events include `purchase_outcome`. Failed operations include `charge_status = unknown` and `decline_status = not_reported`: an App Store failure does not establish that a bank declined payment or that no charge occurred. Categories distinguish network, store problems, purchase restrictions, invalid purchases, unavailable products, configuration and receipt problems. Preserve `rc_code_name` as `error_code_name` when supplied. No card-decline event is fabricated from generic SDK errors or localized error-message text.
- Record leaving a paywall as `paywall_exited`. It does not imply a purchase attempt or decline. Discount impressions report the actual products loaded, including an unavailable offer.
- Record missing-product diagnostics and prevent a different product from replacing an explicitly selected SKU.
- Preserve existing subscription access when a new purchase is cancelled, pending or fails.
- Apply consistent outcome tracking to the main, discounted and legacy paywalls.

## Verification and release

The final simulator Debug build and `git diff --check` passed on 22 October 2026. Existing unrelated compiler warnings remain.

An isolated simulator run with `replay_verification_id = salahalarm-swiftui-20261022-final` produced [QA recording 01a163fb-d47c-7978-b596-3f7e49aa6d56](https://us.posthog.com/project/572656/replay/01a163fb-d47c-7978-b596-3f7e49aa6d56). PostHog received `session_replay_status` for app activation and remote settings with `replay_capture_active = true`. It also returned mobile recording metadata for that session. This verifies event delivery and that capture is active; metadata alone does not prove that playable screen frames arrived.

After the Mac was unlocked, the browser visibly rendered masked screen frames in that QA recording. Text and image masking was preserved. This proves that some actual screen frames reached the player, not just recording metadata.

End-to-end reliability is **not signed off**. A subsequent interaction session, [01a16432-edd2-7faf-9948-faaed18ac43c](https://us.posthog.com/project/572656/replay/01a16432-edd2-7faf-9948-faaed18ac43c), had 166 mobile recording events and two clicks but warned that its first screen snapshot arrived 23 minutes 15 seconds late. That run spans the earlier locked/idle simulator period. A clean foreground relaunch, [01a1644a-6b85-7b8c-91e7-5613d6eb397d](https://us.posthog.com/project/572656/replay/01a1644a-6b85-7b8c-91e7-5613d6eb397d), produced a 20-second recording with 21 mobile events, but its player initially remained blank even after refreshing, disabling inactivity skipping, and seeking. The previously playable recording then also became blank and PostHog explicitly displayed "Your browser couldn't load the player." Clicking Retry recovered that player and its masked screen frame. Thus a blank player here does not establish missing uploaded screenshots; browser/player loading is an additional verified issue. The exact network/extension cause is not established and no browser security protections were disabled. Evidence screenshot: `/tmp/salahalarm-posthog-replay-verified.png`. A repeatable clean-launch playback test remains required before claiming reliable future replay coverage.

Debug verification launches may set `POSTHOG_REPLAY_VERIFICATION_ID`. Such sessions carry `internal_test_session = true` and `replay_verification_id`; exclude them from conversion analysis. No purchases are made during replay verification.

These changes are in the local 2.4/build 22 source. Existing App Store 2.3/build 21 installations keep the old behavior until an updated build is released and installed.

Missing historical frames cannot be recreated. A finite offline queue, device shutdown/crash, network blocking and the project's 30-day retention still limit availability; 100% sampling is not a guarantee that every frame reaches the server forever. Apple authentication and payment sheets may run outside the app and must be diagnosed from purchase outcomes rather than captured financial details.

References: [iOS replay installation](https://posthog.com/docs/session-replay/installation/ios), [mobile recording modes](https://posthog.com/docs/session-replay/mobile), [privacy controls](https://posthog.com/docs/session-replay/privacy).
