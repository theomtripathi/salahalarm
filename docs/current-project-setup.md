# SalahLock Current Project Setup

## Overview
- Platform: iOS
- UI stack: SwiftUI
- Current internal branding in code: `Ramadan Pro`
- Current requested onboarding branding: `SalahLock`
- Repo root: `/Users/pc/Documents/salahlock`

This app already has production-oriented foundations for authentication, subscriptions, prayer times, Qibla, Quran reading, widgets, and local notifications. The current onboarding is short and paywall-oriented, and it does not yet match the requested SalahLock onboarding flow.

## Current Structure

### App shell
- App entry: `/Users/pc/Documents/salahlock/Ramadan Pro/Ramadan_ProApp.swift`
- Main tab shell: `/Users/pc/Documents/salahlock/Ramadan Pro/Views/MainTabView.swift`
- Home/dashboard: `/Users/pc/Documents/salahlock/Ramadan Pro/Views/DashboardView.swift`
- Onboarding coordinator: `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/OnboardingFlowView.swift`
- Onboarding state: `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/OnboardingState.swift`
- Global app state: `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/AppState.swift`

### Main folders
- `Ramadan Pro/Views`: SwiftUI screens and reusable views
- `Ramadan Pro/ViewModels`: presentation/business state
- `Ramadan Pro/Services`: Firebase, RevenueCat, Quran, logout helpers
- `Ramadan Pro/Utils`: routing, location, notifications, prayer times, app state
- `Ramadan Pro/Models`: app data models
- `RamadanWidgetExtension`: widget target

## Frontend

### UI and navigation
- Native SwiftUI app
- Uses `TabView` for primary navigation
- Uses `NavigationStack` per tab
- Uses shared singleton-style state (`AppState`, `OnboardingState`, `NavigationCoordinator`)

### Existing major frontend surfaces
- Onboarding flow
- Sign up / sign in / forgot password
- Dashboard with prayer and fasting information
- Quran tab and reading screen
- Qibla compass screen
- Side menu / profile / delete account
- Subscription paywall screens

### Current visual system
- Existing app styling is dark, premium, Ramadan-oriented
- Custom colors and fonts already exist
- SalahLock white/green/gold onboarding palette is not yet implemented

Relevant files:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Extensions/AppColors.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Extensions/FontExtensions.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Extensions/ViewExtensions.swift`

## Current Features

### Authentication
Implemented:
- Google Sign-In
- Sign in with Apple
- Email sign up
- Email sign in
- Password reset
- Logout
- Delete account

Key files:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Services/FirebaseAuthService.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/ViewModels/AuthViewModel.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/SignUpView.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/LoginView.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/ForgotPasswordView.swift`

### Prayer times
Implemented:
- Location-based prayer time calculation
- Today/tomorrow schedule generation
- Prayer timeline in dashboard
- Local persistence of location for future loads

Key files:
- `/Users/pc/Documents/salahlock/Ramadan Pro/ViewModels/PrayerTimesViewModel.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/PrayerTimesCalculator.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Models/PrayerTime.swift`

### Location
Implemented:
- `when in use` location permission
- Coordinate lookup
- Reverse geocoding to city/country
- Local caching

Key files:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/LocationManager.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Models/Location.swift`

### Qibla
Implemented:
- Compass UI
- Qibla direction calculations
- Live heading updates
- Alignment feedback

Key file:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/QiblaCompassView.swift`

### Quran
Implemented:
- Quran tab
- Quran reading screen
- Quran service/API layer
- Bookmark persistence

Key files:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/QuranTabView.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/QuranReadingView.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Services/QuranAPIService.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Services/FirebaseBookmarkService.swift`

### Notifications
Implemented:
- Local notification authorization request
- Scheduling of prayer-related notifications
- Notification tap handling

Current limitation:
- Existing scheduling is Ramadan-oriented and currently targets `Imsak` and `Iftar/Maghrib`, not a full SalahLock five-prayer reminder model

Key files:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/NotificationManager.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/NotificationDelegate.swift`

### Subscription / paywall
Implemented:
- RevenueCat configuration at app launch
- Offering/package fetch
- Purchase flow
- Restore flow
- Local subscription cache
- Firestore sync of subscription state

Key files:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Services/RevenueCatService.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/ViewModels/SubscriptionViewModel.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/MainPaywallScreenView.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Views/Onboarding/DelayedDiscountPaywallScreenView.swift`

### Widgets
Implemented:
- Widget extension
- Shared app group storage for widget data
- Widget reload helpers

Key files:
- `/Users/pc/Documents/salahlock/RamadanWidgetExtension/RamadanWidget.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/WidgetConfiguration.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/Utils/WidgetHelper.swift`

### Donations / impact
Implemented:
- Donation service
- Donation view model
- User impact persistence

Key files:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Services/FirebaseDonationService.swift`
- `/Users/pc/Documents/salahlock/Ramadan Pro/ViewModels/SadaqViewModel.swift`

## Current Functions and Flow

### Launch flow
Current behavior in `Ramadan_ProApp.swift`:
1. Configure Firebase
2. Configure Google Sign-In
3. Configure RevenueCat
4. Configure notification delegate
5. Show splash screen
6. Decide between onboarding and main app based on auth and subscription state

### Current onboarding flow
Current onboarding is a small enum-driven flow:
- `splash`
- `login`
- `signIn`
- `locationPermission`
- `focusSelection`
- `impactIntroduction`
- `challengeIdentification`
- `widgetShowcase`
- `customizationLoader`
- `mainPaywall`
- `delayedDiscountPaywall`
- `donationSuccess`

Important current behavior:
- If not logged in, flow starts at sign up
- If logged in but not subscribed, app can route directly to paywall
- If subscribed, app goes to `MainTabView`
- Onboarding completion is effectively tied to purchase flow, not a rich user-profile setup

### Main app flow
After onboarding/subscription the app routes into tabs:
- Home
- Quran
- Qibla

The dashboard currently focuses on:
- fasting countdown
- next prayer
- prayer timeline
- Quran progress
- location display

## Backend

There is no standalone custom backend server in the repo. The app currently relies on managed services plus iOS system frameworks.

### Firebase
Used for:
- authentication
- user document storage
- bookmarks
- donations
- subscription sync

Primary file:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Services/FirebaseAuthService.swift`

Firestore collections visible in code:
- `users`
- `bookmarks`
- `donations`

### RevenueCat
Used for:
- offerings/packages
- purchases
- restore purchases
- customer subscription state

Primary file:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Services/RevenueCatService.swift`

### Local/system services
Used for:
- Core Location
- local notifications
- widget app group storage
- `UserDefaults` caching

## Current Data Model

### User model
Current `User` model includes:
- `userId`
- `email`
- `name`
- `createdAt`
- `lastLoginAt`
- `subscriptionStatus`
- `impact`

Key file:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Models/User.swift`

### Subscription model
Current `SubscriptionStatus` already supports:
- active status
- plan type
- start/end dates
- auto renew
- cancelled date
- `trialEndDate`
- `isInTrial`

Key file:
- `/Users/pc/Documents/salahlock/Ramadan Pro/Models/Subscription.swift`

### Missing for new onboarding
Not present yet:
- onboarding answer schema
- onboarding resume/progress schema
- selected distracting apps
- derived habit plan data
- first prayer completion state
- explicit onboarding completion model separate from subscription

## Biggest Gap Relative to SalahLock

The repo currently has no Screen Time app-locking implementation.

Not found in the codebase:
- `FamilyControls`
- `ManagedSettings`
- `DeviceActivity`
- app selection token storage
- shield/app block scheduling

For the current onboarding revamp scope, UI and local selection storage can be added without implementing the actual blocking engine yet.

## Summary

### Strong existing foundations
- auth backend is real
- location/prayer times/Qibla stack is real
- RevenueCat is wired
- Firestore user persistence exists
- widget support exists
- core SwiftUI app shell exists

### What must be added for the new onboarding
- full SalahLock onboarding UI flow
- onboarding-specific design system
- onboarding persistence models
- pre-auth answer caching and post-auth merge
- five-prayer reminder scheduling
- paywall copy and trial-flow refresh
- local app-selection storage for screen 24

### What is explicitly not in the repo today
- actual Screen Time prayer locking
- a Firestore onboarding profile schema
- a long-form dynamic onboarding router
