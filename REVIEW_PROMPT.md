# One-day return review request

Implemented locally, 23 October 2026. Not released by this task.

## Behavior

- Record the first eligible main-app use for a RevenueCat customer with an active purchased or trial entitlement. A local admin bypass or cached `isSubscribed` boolean alone does not qualify.
- On a later foreground opening, wait until at least **24 elapsed hours** have passed. This is not “next calendar date,” and not necessarily 24 hours after download. Existing users without this new timestamp establish it on their first eligible use of this build.
- After a brief foreground delay, fetch RevenueCat customer information. Check identity again after the asynchronous fetch and reject entitlements with a past expiration date.
- Request Apple's native StoreKit review prompt only at an unobstructed point. Defer while an alarm, paywall, settings, Profile or another modal is active. No first-launch/onboarding prompt or three-prayer shortcut remains.
- Preserve the existing once-requested flag. Once the app requests a review, it does not repeatedly ask. Reinstall/data clearing can reset local state; this is not server-wide exactly-once enforcement.

Apple controls whether the native prompt actually appears. There is no result callback proving that a person saw it, submitted a review, or selected a star count. `rating_prompt_requested` records only the API request.

## Why no Yes/No rating gate

The requested “Enjoying the app?” → Yes → five-star review / No → private feedback flow filters reviewers by sentiment. Apple's [App Review Guidelines §5.6.1](https://developer.apple.com/app-store/review/guidelines/#developer-code-of-conduct) prohibit review manipulation/filtered feedback and require the provided review API. The [ratings guidance](https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews) recommends native requests after engagement, without interrupting tasks.

Therefore this implementation uses the neutral native review prompt, with no custom Yes/No dialog or requested/preselected five-star rating. Apple owns the automatic prompt's button styling, not the app.

Profile independently offers both:

- **Leave a Review:** user-initiated App Store write-review link for app ID `6758457826`; any rating is allowed.
- **Send Feedback:** opens the app's existing support form at `https://ramadan-pro.lovable.app/support`.

The support URL was verified from SalahAlarm's actual App Store Connect version metadata and its live page. The form exposes name, email, subject and message. No test message was sent, no personal data is prefilled, and app analytics do not capture the form text. Form delivery itself was not tested by submitting a message.

## Verification

- Focused policy tests cover initial timestamp, paid/trial eligibility, exact 24-hour boundary, less-than-one-day, foreground requirement, modal deferral, unpaid/expired/admin exclusion and legacy once-requested flag.
- Full integrated Debug simulator compilation passed after final code edits. Final diff checks and the rating-policy, annual-trial, trial-journey and purchase-error focused tests passed. Existing duplicate-audio build-resource warnings remain; no compilation errors. Runtime StoreKit display remains controlled by Apple.
- Do not describe this as a completed five-star review or claim a higher review conversion rate without actual evidence.
