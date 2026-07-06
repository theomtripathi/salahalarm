# SalahLock Onboarding Revamp Implementation Plan

## Scope and constraints
- This is a SwiftUI iOS app. Internal app name remains `Ramadan Pro`.
- Onboarding branding changes to `SalahLock`, but file names, targets, and bundle identifiers stay unchanged.
- Only onboarding, auth-adjacent, and listed dependency files should be changed.
- Donation/Sadaqa features are out of scope.
- Screen Time / FamilyControls enforcement is out of scope for this milestone.
- Screen 24 collects and persists app selections only.
- Firestore writes must use merge semantics.
- Pre-auth answers live locally/in memory, then merge into Firestore immediately after auth succeeds.

## File plan

### Replace
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/OnboardingFlowView.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/OnboardingState.swift`

### Modify
- `/Users/pc/Documents/salahlock/Ramadan Pro/Ramadan_ProApp.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/AppState.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Services/FirebaseAuthService.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/NotificationManager.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/LocationManager.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Extensions/AppColors.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/SignUpView.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/LoginView.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/MainPaywallScreenView.swift`

### Create
- `/Users/pc/Documents/salahlock/Ramadan Pro/Models/OnboardingProfile.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Models/OnboardingDerivedPlan.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/ViewModels/OnboardingFlowViewModel.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Services/OnboardingPersistenceService.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/OnboardingRouter.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/PhoneUsageCalculator.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/SalahLockOnboardingView.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/Components/`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/Screens/`

## Design system

Add these colors to `AppColors.swift` without removing existing colors:

```swift
static let slGreen = Color(hex: "#1B6832")
static let slGold = Color(hex: "#C9A028")
static let slCream = Color(hex: "#F9F7F2")
static let slTextPrimary = Color(hex: "#111111")
static let slTextSecondary = Color(hex: "#666666")
static let slBorderDefault = Color(hex: "#E0E0E0")
static let slBorderSelected = Color(hex: "#1B6832")
static let slBackground = Color.white
static let slCardBackground = Color.white
static let slProgressBar = Color(hex: "#C9A028")
```

Create these reusable onboarding components:
- `SLProgressBar`
- `SLPrimaryButton`
- `SLSecondaryButton`
- `SLOptionPill`
- `SLQuoteCard`
- `SLStatCard`
- `SLSummaryCard`
- `SLAuthButton`
- `SLFeatureRow`
- `SLNotificationPreviewCard`
- `SLTimelineRow`

## Data model

### OnboardingProfile
Create a codable profile model for:
- display name
- age range
- prayer frequency
- daily phone usage range
- goals
- obstacles
- relationship with Allah
- deeper struggles
- Muslim background
- gender
- commitment level
- selected distracting apps
- notification/location/screen-time permission states
- first prayer completion timestamp
- onboarding completion timestamp
- last completed screen

### OnboardingDerivedPlan
Create a codable derived plan model for:
- annual phone hours
- annual phone days
- lifetime phone years
- current habit summary
- strength statement
- target consistency date
- commitment progress percent
- primary goal
- top obstacles
- yearly salah moments

### Phone usage calculator
Use a fixed lookup table:

```swift
switch range {
case .r1_2:   return (548, 23, 4)
case .r2_3:   return (912, 38, 6)
case .r3_4:   return (1277, 53, 9)
case .r4_5:   return (1642, 68, 11)
case .r6plus: return (2372, 99, 16)
default:      return (0, 0, 0)
}
```

## Onboarding state and routing

Replace the current small enum/state singleton with a view-model-driven flow:
- `currentScreen`
- `progressValue`
- `profile`
- `derivedPlan`
- `isLoading`
- `loaderProgress`

`OnboardingScreenID` must cover:
- screen0 through screen30, including `screen7A`, `screen7B`, `screen25A`, `screen25B`

Implement deterministic transitions:
- screen0 -> screen1 after auth success
- screen7A -> screen7B with short auto-delay
- screen19 -> screen20
- screen20 auto-advances after loader reaches 100%
- screen25A proceeds to 25B on allow, deny, or skip
- screen30 completes onboarding and exits into the app

Progress bar behavior:
- hidden on emotional/non-form screens and post-question phase
- shown with fixed values on screens 4, 5, 6, 7A, 8, 9, 10, 11, 13, 14, 17, 18

## Persistence

Create `OnboardingPersistenceService` with:
- local save/load via `UserDefaults`
- Firestore merge save after auth and on completion

Local cache payload must contain:
- profile
- derived plan
- last screen

Firestore fields under `users/{userId}`:
- `onboardingProfile`
- `onboardingDerivedPlan`
- `onboardingLastScreen`
- `onboardingCompletedAt`

All Firestore writes use:

```swift
setData(..., merge: true)
```

### Pre-auth merge
- Hold answers locally before auth
- After Google, Apple, email sign-up, or email sign-in succeeds:
  - keep local answers
  - immediately merge them to Firestore
  - continue onboarding from screen1

### Returning user behavior
- If authenticated and onboarding is incomplete, resume from saved screen
- If authenticated and no onboarding payload exists in Firestore, default resume point is screen4
- If subscribed and onboarding is complete, skip onboarding entirely

## Auth integration

Keep existing auth logic intact in:
- `FirebaseAuthService`
- `AuthViewModel`

Change only:
- visual skin in `SignUpView` and `LoginView`
- post-success handoff into the new onboarding flow

Add a Firestore merge method in `FirebaseAuthService` or a dedicated onboarding persistence layer so authenticated users can receive the cached onboarding data immediately after login.

## Notifications

Expand `NotificationManager` from the current Ramadan-style scheduling to five daily prayer reminders.

Add a method like:

```swift
func scheduleFiveDailyPrayerReminders(times: [PrayerTime])
```

Requirements:
- one local notification per prayer
- Fajr, Dhuhr, Asr, Maghrib, Isha
- body format: `🕌 It's time for [prayer name]. Your apps will lock in 2 minutes.`
- use `UNCalendarNotificationTrigger` based on each prayer time
- call after location/prayer times are available

## Location and prayer times

Keep `LocationManager`, `PrayerTimesViewModel`, and Qibla logic as the source of truth.

Changes needed:
- add onboarding-specific permission trigger/handling
- allow screen 25A to request permission and continue cleanly on allow, deny, or skip
- if granted, load city, prayer times, and Qibla data before showing screen 25B
- if denied/skipped, screen 25B renders a safe placeholder state

## Screen 24 app selection

This milestone does not implement actual Screen Time blocking.

Screen 24 requirements:
- show a fixed grid of distracting apps
- allow multi-select
- persist selected app identifiers locally
- merge the selected identifiers into `onboardingProfile.selectedDistractingApps`
- mark skipped state when the user chooses skip

Add an explicit code marker:

```swift
// TODO: SCREEN_TIME_MILESTONE — trigger FamilyControls authorization here
```

## Screen implementation groups

Implement each onboarding screen as SwiftUI views under `Views/Onboarding/Screens/`, receiving:

```swift
@ObservedObject var vm: OnboardingFlowViewModel
```

Key screen groups:
- auth entry
- splash/problem/solution
- question stack
- phone impact reveal
- encouragement and summary
- how it works and commitment
- loader and personalized plan
- notifications/apps/location/Qibla
- first prayer / completion
- social proof / trial framing / reminder / paywall

Visuals and copy should follow the provided onboarding document, while staying consistent with Apple sign-in requirements where relevant.

## Paywall refresh

Use the existing paywall screen as the base and reskin it.

Required paywall behavior:
- title: `start your 3-day free trial`
- weekly option: `$4.99 / week`
- yearly option: `$44.99 / year`
- yearly preselected
- show `3-day free trial` badge on yearly when intro-offer eligible
- show `$0.87 / week` equivalent
- CTA text:
  - `start my free trial` when eligible
  - `subscribe` fallback when not
- footer explains trial and cancellation

On success:
- mark onboarding complete
- update app state
- route to `MainTabView`

## Root app routing

Update app launch routing in `Ramadan_ProApp.swift` to use:
- auth state
- onboarding completion state
- subscription state

Expected behavior:
- not authenticated -> onboarding starts at screen0
- authenticated but onboarding incomplete -> onboarding resumes
- authenticated and onboarding complete but unsubscribed -> paywall edge case
- authenticated and subscribed -> main app

## Analytics

Add Firebase Analytics events:
- `onboarding_screen_viewed`
- `onboarding_auth_success`
- `onboarding_answer_submitted`
- `onboarding_permission_result`
- `onboarding_first_prayer_confirmed`
- `onboarding_paywall_viewed`
- `onboarding_trial_started`
- `onboarding_completed`
- `onboarding_dropped`

Use `screen_id`, `permission`, and `result` parameters where relevant.

## Firestore schema

Under `users/{userId}` merge in:

```text
onboardingProfile
onboardingDerivedPlan
onboardingLastScreen
onboardingCompletedAt
```

Profile fields:
- displayName
- ageRange
- prayerFrequency
- dailyPhoneUsageRange
- goals
- obstacles
- relationshipWithAllah
- deeperStruggles
- muslimBackground
- gender
- commitmentLevel
- selectedDistractingApps
- notificationsPermissionState
- locationPermissionState
- screenTimePermissionState
- firstPrayerCompletedAt
- onboardingCompletedAt
- lastCompletedScreen

Derived plan fields:
- annualPhoneHours
- annualPhoneDays
- lifetimePhoneYears
- currentHabitSummary
- strengthStatement
- targetConsistencyDate
- commitmentProgressPct
- primaryGoal
- topObstacles
- yearlySalahMoments

## Acceptance checklist

### Auth
- Google sign-up starts onboarding successfully
- Apple sign-up starts onboarding successfully
- Email sign-up starts onboarding successfully
- Returning sign-in resumes from saved screen
- Pre-auth values survive auth success

### Personalization
- phone usage range maps to the expected stats
- max 3 goals enforced
- max 3 obstacles enforced
- summary screen reflects actual answers
- commitment maps to correct progress value
- target date is current date + 21 days

### Permissions
- notifications allow/deny/skip all persist correctly
- location allow populates prayer times and Qibla
- location deny/skip shows placeholder state without crashing
- app selections persist locally and merge to Firestore

### Prayer moment
- first prayer screen shows dua and verse
- prayer confirmation writes `firstPrayerCompletedAt`

### Persistence
- app relaunch restores progress from cache
- post-auth merge writes onboarding payload to Firestore
- existing subscribed users skip onboarding

### Paywall
- yearly option selected by default
- trial badge visible only when eligible
- purchase exits into main app
- restore purchases still works

### Regression
- Home, Quran, and Qibla continue working after onboarding
- existing subscribed flows remain intact
