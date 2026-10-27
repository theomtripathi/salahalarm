# SalahAlarm seven-day annual trial

Owner decision: 23 October 2026. Seven days free, then an automatically renewing annual subscription. This is **not** a monthly subscription and is **not** a no-card app-granted pass.

## Local behavior

Main weekly/yearly paywall → genuine annual discount → after explicit discount refusal, check and show the separate seven-day trial → optional exit feedback if refused. Purchase cancellation, pending approval, backgrounding and errors are not offer refusals. Trial refusal never activates access or starts billing. Trial presentation is once per paywall visit; Apple enforces introductory-offer eligibility across the subscription group, not a local once-ever flag.

The free offer is hidden unless RevenueCat confirms the exact product, annual interval, positive renewal price/currency, zero-price free intro lasting exactly one week/seven days, and an explicitly eligible customer with no active subscription. Unknown or unavailable eligibility fails closed. Eligibility, account identity and displayed price/currency are rechecked before checkout. No other product is substituted. Apple still makes the final purchase/eligibility decision in its confirmation sheet.

After verified access starts, Home shows a small routine checklist, actual trial dates, and Apple subscription management. There is no guilt messaging, artificial urgency, extra permission prompt, reminder campaign or guarantee of increased retention. Actual alarm configuration and prayer logging are measured separately from viewing Home.

## App Store Connect — configured, not submitted

Sign in at https://appstoreconnect.apple.com/apps/6758457826 and verify the correct app/bundle.

On 24 October 2026, created the new auto-renewable subscription in existing group `Subscription` (`21911655`), Apple subscription ID `6826409225`. The saved group table confirms level **3**, matching the regular yearly plan; other products' levels were not changed.

| Field | Value |
| --- | --- |
| Reference name | SalahAlarm Annual - 7-Day Trial |
| Product ID | `yearlydiscountedtrial` |
| Subscription duration | 1 year |
| US base recurring price | $19.99/year, as approved by owner |
| Introductory offer type | Free |
| Introductory duration | 1 week |
| English (U.S.) display name | SalahAlarm Annual |
| English (U.S.) description | Premium prayer alarms and tools, billed annually. |

Saved and verified: **1 Year Upfront** availability in all 175 offered countries/regions; US renewal price **$19.99/year**, with Apple-calculated local price tiers (no manual country overrides); **Free for the first week**, starting **24 October 2026**, **No End Date**, in those 175 countries/regions. Monthly-with-a-12-month-commitment billing was **not** configured. Family sharing, parent tax category and existing purchase-option defaults were left unchanged.

The product remains **Prepare for Submission**. A real in-app trial review screenshot, final review metadata, Apple sandbox verification and submission/approval are still outstanding. No customer purchase or app release was made. Saved setup evidence: `/tmp/salahalarm-apple-seven-day-trial.png`.

Confirm availability, localization length limits, territories, tax/category, review metadata and screenshots in the actual form. Do not create a second subscription group merely to reset eligibility; do not overwrite the current `yearlydiscounted` pay-now product. Do not add the trial to weekly or regular yearly products unless intentionally changing those offers too. Product/introductory-offer approval and availability may block testing/release.

The App Store handles currency-specific price tiers. Preserve any intended country overrides. Show real StoreProduct prices after propagation. The monthly equivalent is annual price / 12, formatted with that product's currency; $19.99/year rounds to $1.67/month. No $1.66 or $19.99 display string is hard-coded in production trial UI.

## RevenueCat — catalog configured

Verified on 23 October 2026: SalahAlarm is inside the RevenueCat project named **sonn apps**, project `8a376da3`, App Store app `app4e20e4089a`, with bundle ID `com.Ramadan-Pro`. The earlier project-name-only check did not establish this identity; matching the actual bundle resolves it. Do not use the unrelated Scroll the Quran project.

The owner reported accepting the updated Paid Applications Schedule, and Apple's Business page was verified as **Active** before creating the product. No legal agreement was accepted by the agent. Existing subscription group: `Subscription`, ID `21911655`.

### Completed RevenueCat discount prerequisite

On 23 October 2026 the existing approved Apple product `yearlydiscounted` (Apple subscription ID `6801233878`, one-year duration) was imported into this RevenueCat App Store app as product `prod42f3c406d6`. It was attached to existing entitlement `sonn apps Pro` (`entl05397af9ca`). The separate offering **`yearly-discounted`** (`ofrngba3fcf6a9c`) was created with annual package `$rc_annual` pointing to this exact product. The saved offering page was verified visually. Existing prices, other products and default offerings were not changed.

The older RevenueCat product `com.ramadanpro.yearly.discount` is marked **Not found**; it was left untouched, not substituted for the approved exact product. This configuration repair is not proof of a completed purchase or a production conversion.

### Completed RevenueCat trial configuration

On 24 October 2026, imported exact App Store SKU `yearlydiscountedtrial` as RevenueCat product **`prod85ba7f880c`**, attached it to existing entitlement **`sonn apps Pro`** (`entl05397af9ca`), and verified the success message and product's **1 Entitlement** state. Created offering **`yearly-trial`** (`ofrng13fd8830fa`), display name **Seven-day free trial, then discounted annual SalahAlarm subscription**, with annual package **`$rc_annual`** linked only to that exact App Store product. Verified the saved offering page and screenshot `/tmp/salahalarm-revenuecat-trial-configured.png`. Neither default offering nor `yearly-discounted` was changed. No Test Store or Android product was added. RevenueCat initially reported **Missing Metadata** for the new Apple draft; catalog import is not Apple approval or a successful StoreKit product fetch.

The configuration contract below is now populated; retain it when maintaining the catalog:

1. Import App Store product `yearlydiscountedtrial` into the **same existing premium entitlement** used by the app. Verify the production app/bundle and credentials, including RevenueCat's required App Store In-App Purchase key for StoreKit 2 offers.
2. Create offering:

   - **Identifier:** `yearly-trial`
   - **Description:** `Seven-day free trial, then discounted annual SalahAlarm subscription`

3. Add the annual package (`$rc_annual`) linked to exact product `yearlydiscountedtrial`.
4. Do **not** make `yearly-trial` the current/default offering. The app fetches it by identifier only after discount refusal. Keep the main current offering and `yearly-discounted` intact.
5. Configure the Debug RevenueCat Test Store separately if using it. Its annual products must actually have a one-year period; a SKU named “yearly” configured as one month is rejected. A Test Store purchase does not prove Apple sandbox eligibility/billing.

## Measurement

- `trial_offer_shown`, `trial_offer_accepted` (CTA only), `trial_offer_declined` (explicit refusal), `trial_offer_unavailable` (technical/eligibility reason).
- Existing checkout/outcome events retain paywall view/attempt IDs, `offer_stage=final_trial`, actual product/price/currency and `trial_requested`.
- `purchase_completed` means the purchase operation completed, **not necessarily a charge**. Check `subscription_period_type` and `charge_status` before treating it as paid conversion.
- On a verified trial, `revenue_amount=0`; `price_amount`/`renewal_price_amount` describe the annual product's renewal price, not money collected. Do not sum the displayed annual price as trial revenue.
- `trial_started` requires verified entitlement period `.trial`, with the real end date; it is not emitted from a button tap.
- A completed transaction without confirmed active access becomes `purchase_pending` with `failure_stage=entitlement_verification` and `checkout_status=completed`, not `purchase_failed`. Restore/support is offered rather than telling the customer to pay again.
- Free trials use AppsFlyer `af_start_trial`, TikTok `StartTrial`, not paid annual purchase revenue. Paid conversion/renewals, refunds and billing issues must come from verified RevenueCat lifecycle events/webhooks; the app cannot observe an off-device renewal reliably.
- `trial_journey_viewed` is a view, not a useful action. `trial_journey_action` milestones measure actual setup/logging/return actions. Local deduplication is not a server exactly-once guarantee, and can reset after reinstall/logout.
- Journey `trial_day` is a zero-based **UTC calendar-day** offset: D0 is the start date and D1 the following UTC date, not necessarily 24 hours later. Useful-return milestones require a real action, not opening Home. Milestones and daily views are locally scoped by customer/trial epoch. Do not mix this with rolling 24-hour retention definitions in reports.

Do not infer why a person refused without feedback. Neither an unknown StoreKit error nor an offer refusal proves a bank declined a payment. Trial expiry also does not prove conversion, cancellation or payment failure.

## Release gates

- [x] Standalone annual-trial policy/pricing tests: 30 checks passed.
- [x] Existing purchase-error classification tests: 10 passed.
- [x] Trial-journey deduplication, UTC-day, eligibility and action checks passed.
- [x] Full integrated Debug simulator build passed after final code edits; `git diff --check` passed. Pre-existing duplicate-audio-resource and compiler warnings remain; no build errors.
- [ ] Verify real trial UI at standard and large Dynamic Type sizes, with narrow screens/long currency strings.
- [x] App Store product/pricing/free intro and RevenueCat offering/entitlement configured under the verified accounts. Apple review screenshot, submission and approval remain outstanding.
- [ ] Apple sandbox eligible purchase: confirmation sheet says seven days free then annual charge; entitlement `.trial` and exact expiry arrive.
- [ ] Sandbox ineligible/existing subscriber, unavailable products, offline, account switch and changed terms never silently switch to a full-price purchase.
- [ ] Cancel/pending/failure outcomes and refusal remain separate; no access from a failed checkout.
- [ ] Restore/relaunch, trial cancellation, expiration and paid renewal checked with real lifecycle data.
- [ ] Verify entitlement gating safely handles running alarms and SalahLock on expiry. This change does not redesign all pre-existing access/extension expiry behavior.
- [ ] Verify incoming PostHog events and RevenueCat lifecycle integration, then release a reviewed build. No production release has been made by this task.

## Primary references

- [Apple introductory-offer setup](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions): actual free trial and group eligibility.
- [RevenueCat iOS offers](https://www.revenuecat.com/docs/subscription-guidance/subscription-offers/ios-subscription-offers): Apple applies eligible intros; required setup/keys.
- [Apple purchase design](https://developer.apple.com/design/human-interface-guidelines/in-app-purchase): show total localized billing, automatic renewal and restore/management.
- [Research and retention plan](TIME_TO_VALUE.md): Roblox, King/Mojang and Unity sources; game practices are hypotheses for this app, not promised results.
