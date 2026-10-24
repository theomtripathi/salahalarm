# SalahAlarm: offer, checkout and decline analysis

Updated 23 October 2026. Target: PostHog project 572656. Schema version 3 is local source, not a retroactive repair of older events.

## Latest forensic finding

Rechecked the preceding 30 days on 23 October 2026, excluding `internal_test_session=true`: all **116 `purchase_failed` events across 83 sessions** had `error_reason = Purchase was cancelled`. These are event/session counts, not unique buyers or confirmed card declines. Historical `purchase_declined` represented leaving a paywall; it cannot retrospectively identify a bank decision or a final-discount refusal. The new schema fixes future interpretation after release; it does not recover uncollected historical reasons.

## What each outcome actually means

| Observation | Event | Interpretation |
| --- | --- | --- |
| Main paywall visible after product loading | `paywall_viewed` | A visit; inspect `plans_loaded` before treating it as a purchasable impression. |
| Main close button tapped | `paywall_close_tapped` | User tried to leave, not a payment decline. |
| Final annual discount shown | `win_back_modal_shown` | The existing `yearlydiscounted` product was loaded, lower priced than ordinary annual, and in the same currency. |
| Final offer could not be offered | `win_back_offer_unavailable` | Product absent or not a lower comparable price; not a user refusal. |
| SKU billing interval doesn't match advertised plan | `paywall_product_rejected` | Invalid product configuration; SKU is excluded rather than displayed under a false billing label. |
| Final offer CTA tapped | `win_back_offer_accepted` | Interest/CTA acceptance, not proof of payment. |
| Final offer X/No thanks tapped | `win_back_offer_declined` | Explicit offer refusal; inspect `exit_action` and prior checkout outcome. No bank verdict. |
| Purchase CTA tapped | `purchase_initiated` | An attempt began at the UI layer. |
| RevenueCat purchase invoked after SKU validation | `purchase_checkout_started` | SDK checkout requested. Does not prove Apple's payment sheet rendered. |
| RevenueCat returns a successful purchase | `purchase_completed` | Confirmed client purchase result, not merely CTA acceptance. |
| Explicit RevenueCat/StoreKit cancellation | `purchase_cancelled` | User cancelled checkout. It does not tell us whether price, timing, or another concern caused it. |
| Payment awaits approval | `purchase_pending` | Pending, not failed. |
| Explicit purchase permission restriction | `purchase_not_allowed` | Device/account does not allow purchases. Not an issuer/card decline. |
| Other actual purchase error | `purchase_failed` | See category and SDK domain/code. A network/store/receipt/configuration problem is not automatically a bank rejection. |
| Optional exit reason answered or skipped | `paywall_exit_reason_submitted` | `reason_source=user_reported` for an answer, `skipped` otherwise. |
| Explicit paywall exit | `paywall_exited` | Which stage and action ended this visit. |
| App backgrounded on paywall | `paywall_backgrounded` | Context only, including `checkout_in_progress`. Do not count it as refusal or failure. |

## Correlation and segmentation

The active SwiftUI paywall's visit/offer/purchase events include `paywall_id`, `paywall_view_id`, `paywall_placement`, `offer_stage` (`main`/`final_discount`), `offer_product_id`, `final_offer_shown`, `had_purchase_attempt`, and `last_checkout_outcome`. Checkout events additionally carry an immutable `purchase_attempt_id`, exact `plan_id`, billing period, numeric `price_amount`, localized `price_billed`, currency, and final-offer flag. Join outcome events to the initiating attempt, not just to whichever plan a user selected most recently.

New failed/restricted/pending/cancelled outcomes retain normalized `error_category`, safe `error_reason`, SDK `error_domain`/`error_code`, `error_code_name` when supplied, and immediate underlying domain/code. No raw receipts, card data, arbitrary error userInfo, or authentication text are added. Missing packages have `failure_stage=product_lookup`, `checkout_status=not_started`, and `charge_status=not_attempted`. Ambiguous checkout errors retain `charge_status=unknown` and `decline_status=not_reported`.

The legacy paywalls retain their separate `legacy_main`/`discount_yearly` identifiers and outcome categorization. Full visit/attempt/final-offer correlation described above belongs to `current_swiftui_paywall`; do not combine legacy event counts into a visit-ID denominator.

## Reasons: observed versus reported versus unknown

After the final offer is declined, an optional sheet offers these structured answers:

- `price_too_high`
- `not_ready`
- `want_to_try_first`
- `checkout_problem`
- `other`
- `not_provided` when skipped or dismissed

There is no required free-text field and Skip remains available. A reported `checkout_problem` is a user's experience, not a verified payment-provider error. Analyze it alongside that visit's actual checkout events. Do not infer “too expensive” from closing, cancellation, country, or replay behavior. Do not report skipped reasons as known.

## Analyses to configure in PostHog

Use only `analytics_schema_version=3` for the new taxonomy, exclude `internal_test_session=true`, and scope to `paywall_id=current_swiftui_paywall` where visit IDs are required. Always show the time range, cohort, denominator and number of unknown/skipped cases.

1. **Download-to-purchase proxy:** ordered person funnel `app_installed → paywall_viewed → purchase_initiated → purchase_completed`, with a declared conversion window (for example 7 days). `app_installed` is first app launch captured by the SDK, not the count of App Store downloads; compare App Store Connect separately. Users installed before the measurement window may not have an install event.
2. **Main-paywall conversion:** `paywall_viewed → purchase_initiated → purchase_checkout_started → purchase_completed`, hold `paywall_view_id` constant and restrict all steps to `offer_stage=main`. Include `plans_loaded=true` on the impression. Count unique visits, not taps; show retry counts separately.
3. **Final-offer recovery:** `win_back_modal_shown → win_back_offer_accepted → purchase_checkout_started → purchase_completed`, same visit, `offer_stage=final_discount`, exact `plan_id=yearlydiscounted` on checkout/outcome. A recovered purchase must belong to that final offer, not a subsequent ordinary yearly purchase.
4. **Attempt outcome mix:** one row per `purchase_attempt_id`; cancelled / pending / not allowed / failed / completed / no terminal result observed. Report repeated attempts and later success separately. Missing terminal events are unknown/incomplete, not invented failures.
5. **Technical failure breakdown:** `purchase_failed` by `error_category`, domain/code, product, currency, app build and OS. Drill into linked session replay. Keep restriction events and cancellations out of this failure series.
6. **Offer rejection:** final offer declined / final offer shown, unique visits. Break down by X versus No thanks and whether there had already been a checkout attempt. This is offer refusal, not issuer decline rate.
7. **Stated reasons:** one response per visit, show skipped/unknown alongside the answered distribution. Link `checkout_problem` reports to actual attempt outcomes. Responses are a self-selected subset, not a causal explanation of every drop-off.
8. **Availability and collection health:** product-unavailable events, impressions with `plans_loaded=false`, final offers unavailable, initiated attempts with no SDK-start event, attempts without an outcome after the declared observation window, and replay capture status. These surface missing offers or missing data without blaming customers.

## Payment truth and remaining server requirement

Apple/RevenueCat generic errors do not reliably expose an issuer's decline reason such as insufficient funds or a rejected card. `purchase_not_allowed` means a purchase restriction, not “card declined.” We will not manufacture a `payment_denied`/bank-decline label from an opaque error or translated message.

This app's `purchase_completed` measures the synchronous client result. For a complete revenue ledger—including approval completed after the app closes, renewals, refunds, billing issues, and purchases made on another device—connect RevenueCat's server-side events/webhooks to PostHog with stable user IDs and event-ID deduplication. Keep server revenue events separate from client checkout events and reconcile them. There is no backend/webhook project in this checkout and no server connection has been deployed by this change. Pending approval must not silently become a failed payment because a client event is missing.

## Replay and privacy

SwiftUI screenshot mode is enabled. Default masking remains on for account/personal screens and system sandboxed views. Public onboarding introduction screens and the three input-free paywalls are explicitly readable. The optional exit-reason sheet remains masked in replay; its structured response is the intended analytics source. Passwords, account fields, and Apple payment sheets are not exposed.

Startup requests bounded foreground layout passes after recording activation to cover window-attachment timing. This does not reset the SDK/session or assert that frames were delivered. `replay_capture_active` is a capture diagnostic, not a server-delivery guarantee. The previous browser-side player-loading error is distinct from the app's masking or screenshot configuration; do not disable browser security to work around it.

## Configuration checks from this investigation

- Subscription fetching now preserves the current offering and additionally loads only product `yearlydiscounted` from the explicitly named `yearly-discounted` offering, if it is not already in the current offering. It no longer selects an arbitrary first offering when no current offering is configured. Failed fetching clears stale package state.
- Products are validated against their real SDK subscription period before becoming plans: weekly requires one week/seven days, yearly one year/twelve months, monthly one month (monthly remains excluded from these paywalls). SKU names alone do not determine billing truth.
- The RevenueCat **Test Store**, not production App Store, reported `com.ramadanpro.yearly` as `SubscriptionPeriod: 1 month` during QA. The new guard excludes that configuration. Fix its Test Store subscription period and ensure the exact final-offer product exists in the Test Store offering before testing the annual/discount screens there. Production App Store product metadata was not independently inspected through an App Store Connect connection.
- PostHog received schema-v3 internal QA events, including `paywall_close_tapped`, `win_back_offer_unavailable` and `paywall_exited`. In the first test the final product was not loaded; that was correctly recorded as availability failure, not user refusal. QA events remain marked `internal_test_session=true`.
- The actual RevenueCat Test Store Cancel button produced `purchase_cancelled`, and its Test failed purchase button produced `purchase_failed` (SDK code 42, simulated Test Store failure). Distinct attempt IDs were present on initiation, SDK invocation and outcomes. No valid/real purchase was executed. These tests exercise client classification, not bank authorization or production StoreKit.
- The native SDK/server event timestamps for two immediate steps can differ by a few milliseconds; use the immutable attempt ID to correlate an attempt and its outcome. Do not infer missing payment attempts from sub-second clock/batch ordering alone.
- During the live playback check PostHog's page returned a recording-loading error. Its [US status page](https://www.posthogstatus.com/us) reported an active partial outage affecting the application and feature-flag endpoints (update 22 October 2026 21:00 UTC, 23 October 02:30 IST). This is a verified external incident, not proof that any particular frame was lost. Readable replay playback remains a release acceptance check; recording metadata alone is insufficient.

## Release acceptance

- Compiler and classifier regression suite must pass.
- Verify readable pricing/copy in an actual uploaded replay, not just its metadata row.
- Verify dummy account inputs stay masked without submitting authentication.
- Verify main close → one final offer → optional reason → exit, including Skip/swipe dismissal.
- Verify a final offer CTA is not counted as `purchase_completed` without SDK success.
- Use sandbox/Test Store to exercise cancellation, pending, restrictions, missing SKU and real failure paths. Do not test a real charge without authorization.
- Release/install the new app. Historical events and historical missing frames cannot be reconstructed by this code change.

The measurement guide is also saved inside [PostHog](https://us.posthog.com/project/572656/notebooks/CiHKTt0g). It documents definitions and analysis configuration; it is not a deployed dashboard or an automated revenue reconciliation backend.

References: [PostHog iOS replay](https://posthog.com/docs/session-replay/installation/ios), [privacy controls](https://posthog.com/docs/session-replay/privacy), [RevenueCat error handling](https://www.revenuecat.com/docs/test-and-launch/errors).
# Seven-day trial addition — 23 October 2026

Local trial implementation extends the existing schema with `offer_stage=final_trial`. See [TRIAL_SETUP.md](TRIAL_SETUP.md) for exact product configuration, new events, tests and release gates. It has not been activated in App Store Connect or released. `purchase_completed` describes a completed purchase operation, including a possible free trial: exclude `subscription_period_type=trial` from paid conversions. Use verified RevenueCat lifecycle data for actual trial-to-paid renewal and billing outcomes, not the trial CTA or expected annual price. All earlier production findings below describe the versions/time windows stated there, not this unreleased trial flow.

