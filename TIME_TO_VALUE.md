# SalahAlarm: seven-day welcome experience and retention plan

Research and code audit: 23 October 2026. **Owner selected model B: seven-day App Store trial, then auto-renewing annual subscription.** Local trial flow and first-routine checklist are implemented; integrated Debug simulator build, focused tests and diff checks pass. App Store/RevenueCat configuration and sandbox validation remain pending. No trial product, App Store offer, or reminder campaign has been activated. Model A below is historical discussion, not the selected behavior.

Approved US renewal target: $19.99/year. Its rounded monthly equivalent is $1.67, not $1.66. The UI reads the actual localized store price, not this planning amount. See [trial setup and release checklist](TRIAL_SETUP.md).

Implemented scope: eligibility-checked post-discount trial, clear auto-renewal terms, actual entitlement trial dates, Home's alarm/prayer checklist and subscription-management link, action-based retention events, and removal of the pre-value rating prompt. A full reminder campaign, production experiment and RevenueCat lifecycle/webhook integration are not implemented. Historical proposals below remain future work unless listed here.

## 1. Current time-to-value

The app promises a prayer reminder that leads to action, plus useful prayer tools. Onboarding configures preferences before monetization, but someone declining the main paywall and final annual offer is returned to signup rather than allowed to experience the core routine. Configuration is not the same as receiving that first useful result.

The first win should be one working prayer alarm and a clearly understood dismissal routine, followed by a first routine log when the user chooses. We cannot guarantee a prayer time falls within the next few minutes, so offer an explicitly labelled alarm test rather than pretending a real prayer was completed.

## 2. Friction map

| Stage | Friction | Proposed response |
| --- | --- | --- |
| Main offer | Asked to pay before experiencing the core value | Preserve transparent weekly/yearly choices. |
| Final discount | Another monetary decision | Show the genuine localized annual discount once, not an invented or endlessly repeating deal. |
| Discount refused | Currently returns to signup | Offer one clearly explained seven-day welcome experience, if eligible. No automatic activation merely from closing a screen. |
| Access begins | User may not know what to do next | Show one setup task: choose one alarm, test it, understand how to stop it. |
| Returning | Progress may be unclear | Show next prayer action and recent personal progress, not a leaderboard of religious worth. |
| Access ending | Surprise loss of features or charging | Explain the end date and applicable payment behavior clearly before acceptance; preserve history and provide an easy exit. |

## 3. First-win definition

- Immediate: successfully configure and test one alarm; request only the permissions that action needs.
- First real session: view the next prayer reminder and understand the action required.
- First routine log: gentle acknowledgement without implying the app verifies spiritual merit.
- Returning: one obvious next action, not a fresh onboarding questionnaire.

## 4. Quick-win asset

**Your first prayer routine**: a short in-app checklist with an alarm setup action, an optional labelled test, and a preview of what happens at prayer time. Reuse the existing alarm/settings UI and stored onboarding preferences. Do not invent alarm delivery guarantees or bypass iOS permissions.

## 5. Proposed onboarding and retention loop

Main paywall → one final annual discount → seven-day welcome offer → informed acceptance → first-routine checklist → useful daily return → transparent end-of-access decision.

- Hour 0: explain exactly what is free, its end date, and whether it renews; then configure one working alarm.
- First day: show the next useful action and acknowledge a completed setup/routine milestone once.
- Days 2–3: concise progress recap; a missed day is a chance to restart, not a penalty or a lost paid reward.
- Days 4–6: keep the core experience familiar; make a single relevant optional feature discoverable, such as widgets or SalahLock.
- Before the end: a clear in-app access/billing notice. Optional notification only with permission and a delivery preference; no repeated marketing alerts on top of prayer alarms.
- Day 7: show what the user actually used and an optional subscription decision. No fabricated streaks, compulsory reviews, countdown tricks, or unsubstantiated discount superlatives.

This is a retention hypothesis to test, not a prediction that religious-app behavior will match a game's metrics.

## 6. Billing decision required

### A. Recommended for the owner's requested “pay only if you choose” promise

A seven-day app-granted welcome pass: no subscription purchase, card authorization, auto-renewal, or automatic charge. At expiry the user may explicitly purchase through Apple. This is not an App Store introductory subscription trial and should not be labelled as one in payment analytics.

Suggested copy:

> Your next step toward salah is on us.
>
> Enjoy SalahAlarm free for 7 days as you build your prayer routine. No card and no automatic charge. If it helps you, you can choose to subscribe. If not, there's nothing to cancel.

Primary action: **Start my free 7 days**. Secondary action: **Not now**. Dates and duration must come from the actual grant, not display-only text. Exact included features must match implementation.

### B. If an Apple-managed subscription trial is intended

An eligible person accepts Apple's subscription purchase sheet. The subscription automatically renews at the disclosed localized price unless cancelled. Copy must say so; “nothing to cancel” would be false.

Read the introductory-offer duration and eligibility from StoreKit/RevenueCat. Apple supports one-week and two-week trial durations, not a custom fifteen-day introductory option. Eligibility is limited across the subscription group. An introductory offer is attached to a product: adding it to an existing product can affect eligible purchases of that product at other paywall placements too. It is not a display-only offer that can be safely restricted by hiding its copy on another screen.

Before App Store changes: confirm billing model, exact product, target storefronts and dates, existing offer conflicts, regular renewal price, and eligibility behavior. The owner will sign in; no credentials or paid purchase should be entered by automation. No App Store offer has been created in this turn.

## 7. Access architecture and expiry safety

Never set `isSubscribed=true` to represent an app-granted pass. Preserve RevenueCat's paid/Apple-trial entitlement as a separate source of truth.

The code audit found separate gates in RootRouterView, AlarmViewModel, shared WidgetConfig and widget timelines, AppLockManager/FamilyControls monitor, legacy login routing, and background notification scheduling. A no-card pass needs one effective-access decision shared with those consumers and an explicit expiry record.

Acceptance must persist once-only eligibility using a deliberate identity policy. A UserDefaults flag alone resets on reinstall/logout and is not reliable abuse prevention. Choose account-backed/server-issued eligibility or clearly documented device-only limitations; do not promise globally once-only access without enforcement.

At expiry: do not strand a running alarm or trap the person behind a SalahLock shield. Permit safe dismissal/unlocking, stop new restricted schedules/shields, and preserve saved history/preferences. Extensions need time-aware access checks even when the main app is closed. Background execution is not an exact-expiry timer.

## 8. Measurement and experiments

Keep these events separate from `purchase_completed`:

- Welcome offer shown / accepted / declined / unavailable
- App-granted access started / expired (if model A)
- Apple trial purchase outcome and verified entitlement state (if model B)
- First alarm configured / labelled test completed
- First routine logged
- Active return day with a stable cohort and access source
- Subscription purchase after the welcome experience

Reuse existing paywall visit and purchase-attempt IDs. Persist experiment assignment and analyze the original cohort even if someone later buys or expires. Measure actual D1, D7 and later returns; a day-eight return is not a day-seven return. Separate opens from useful actions. Also track conversion, refunds/cancellations, permission opt-outs, alarm reliability and complaints so a nominal retention improvement cannot conceal harm.

Start with seven days as a simple product hypothesis. Do not select seven versus fourteen days on a few early successes or use game-industry retention rates as SalahAlarm targets. Use sufficient samples, a declared observation window, and a preselected success metric before deciding a winner. No production experiment has been activated.

## 9. Research applied

- **Roblox onboarding engineering/design guidance:** teach the essential loop quickly, expose a small early goal, and test onboarding steps. Application here: one working alarm before more feature discovery, not a longer sales funnel. [Source](https://create.roblox.com/docs/production/game-design/onboarding)
- **King/Mojang leaders discussing Candy Crush and Minecraft:** preserve trust and familiar core value while using telemetry plus user feedback to evolve the experience. Application here: honest billing, reliable reminders, gentle progress, and no guilt-based reactivation. [Microsoft Game Dev source](https://developer.microsoft.com/en-us/games/articles/2026/05/art-and-science-of-evergreen-games-minecraft-candy-crush/)
- **Roblox experimentation guidance:** keep assignment/cohort attribution stable and account for sample size and novelty effects. Application here: compare access experiences using declared D1/D7 and purchase outcomes rather than stopping at a short-term conversion spike. [Source](https://create.roblox.com/docs/production/experiments)
- **Unity funnel guidance:** use progression funnels to find unclear or slow early steps. Application here: inspect setup → test → first useful routine, separately from offer → purchase. [Source](https://unity.com/blog/games/introducing-funnels-sql-data-explorer-meaningful-insights-to-grow-your-game)
- **Apple:** introductory trials require real product configuration and eligibility checks, and auto-renew after the introductory period. [Setup](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions), [implementation](https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app)

## 10. Implementation sequence after the billing choice

1. Confirm model A or B and validate the exact promise against actual entitlements.
2. Implement the shared access/eligibility layer, expiry boundary tests and extension safety.
3. Add the one-time post-discount welcome offer, with an accessible clear refusal action.
4. Add the first-routine checklist and a non-intrusive progress/return experience.
5. Add deduplicated cohort and milestone tracking without fabricating purchases.
6. Configure App Store introductory offers only if model B is chosen; validate real product eligibility in sandbox.
7. Build and test acceptance, repeat claims, expiry, offline/relaunch, account changes, purchase conversion, existing subscriber behavior, queued alarms and active shields. Then release a reviewed build.
