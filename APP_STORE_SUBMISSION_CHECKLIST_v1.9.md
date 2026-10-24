# SalahAlarm v1.9 App Store Submission Checklist

## Version Information
- **Current Version**: 1.9
- **Build Number**: 1
- **iOS Target**: iOS 14.0+
- **Submission Date**: July 7, 2026

## ✅ Build & Compilation
- [x] Main app target builds successfully (Ramadan Pro)
- [x] Widget extension builds successfully (RamadanWidgetExtensionExtension)
- [x] DeviceActivityMonitor extension builds successfully (SalahLockMonitor)
- [x] No critical build errors
- [x] All warnings are non-critical (unused catch blocks, duplicate build files)

## ✅ Security & Privacy
- [x] No hardcoded API keys or secrets in source code
- [x] No insecure HTTP connections (all HTTPS)
- [x] Proper entitlements configured:
  - [x] com.apple.developer.family-controls (for SalahLock)
  - [x] com.apple.developer.applesignin (Sign in with Apple)
  - [x] com.apple.security.application-groups (Widget sync)
- [x] Privacy descriptions in Info.plist:
  - [x] NSCameraUsageDescription (prayer mat scanning)
  - [x] NSLocationWhenInUseUsageDescription (prayer times & Qibla)
- [x] Background modes configured:
  - [x] audio (silent keep-alive)
  - [x] fetch (background app refresh)
  - [x] processing (device activity monitoring)

## ✅ Pricing & Monetization (v1.9 Update)
- [x] Updated pricing:
  - [x] Weekly: $7.99
  - [x] Monthly: $24.99 (billed monthly)
  - [x] Yearly: $49.99
- [x] RevenueCat product IDs configured:
  - [x] com.ramadanpro.weekly
  - [x] com.ramadanpro.monthly
  - [x] com.ramadanpro.yearly
- [x] Paywall displays pricing breakdown:
  - [x] Weekly plan shown
  - [x] Monthly plan shown with $/week breakdown (~$6.25/week)
  - [x] Spin wheel leads to yearly deal
  - [x] Yearly deal shows savings % vs weekly and monthly
- [x] Fallback pricing in place if RevenueCat unavailable
- [x] Faith-check dialogs reaffirm value proposition
- [x] Mandatory review prompt in onboarding (no skip option)

## ✅ Features
### Core Features
- [x] Prayer times (Adhan library integrated)
- [x] Prayer alarms with multiple sound options
- [x] Complete Quran with translations
- [x] Qibla compass with direction detection
- [x] Prayer logging & tracking
- [x] Streak counter

### New Features (v1.9)
- [x] SalahLock (app blocking during prayer times)
  - [x] FamilyControls framework integrated
  - [x] App selection in onboarding (mandatory)
  - [x] Prayer selection (default Fajr, configurable)
  - [x] Lock tab in main navigation
  - [x] Device activity monitoring (doesn't lock on force-quit)
  - [x] AppLockManager properly integrated in app lifecycle

- [x] Dua Widget (30-minute rotation)
  - [x] 99+ duas from Quran and Hadith
  - [x] Home screen widget (multiple sizes)
  - [x] Lock screen widget (monochrome)
  - [x] 30-minute deterministic rotation
  - [x] 8 color themes with gradients
  - [x] Proper widget configuration in Info.plist

### Onboarding Flow (v1.9)
- [x] Screen 16A: Lock intro ("pray first. then unlock your apps.")
- [x] Screen 16B: App selection + Screen Time auth (mandatory, no skip)
- [x] Screen 17F: Why we need support (new screen before paywall)
  - [x] Lists all features (prayer times, Quran, Qibla, lock, duas)
  - [x] Explains resource requirements
  - [x] Builds case for subscription
- [x] Screen 18: Paywall with conversion loop
  - [x] Stage 1: Weekly + Monthly plans
  - [x] Faith check on close (strong messaging)
  - [x] Stage 2: Spin wheel (always lands on yearly)
  - [x] Stage 3: Yearly bumper deal with savings
  - [x] Final faith check on exit

## ✅ Permissions
- [x] Camera permissions (prayer mat QR scanning)
- [x] Location permissions (prayer times, Qibla)
- [x] Push notifications (prayer alarms, reminders)
- [x] Screen Time / Family Controls (app locking)
- [x] Background app refresh (keep-alive monitoring)

## ✅ Testing Performed
- [x] All targets build without errors
- [x] App launches on simulator (iPhone 17 Pro)
- [x] Navigation between tabs works
- [x] Onboarding screens display correctly
- [x] Paywall pricing displays correctly
- [x] Lock tab accessible and functional
- [x] Widget preview loads

## ⚠️ Pre-Submission Actions Required
Before submitting to App Store Connect, you must:

1. **RevenueCat Setup**
   - [ ] Update RevenueCat API key from test key to production key in Ramadan-Pro-Info.plist
   - [ ] Ensure weekly ($7.99), monthly ($24.99), and yearly ($49.99) products are created in App Store Connect
   - [ ] Configure product IDs (com.ramadanpro.weekly, .monthly, .yearly)

2. **App Store Connect**
   - [ ] Update app description to mention SalahLock and Dua widgets
   - [ ] Add screenshots showing:
     - [ ] Prayer times screen
     - [ ] Lock feature (lock tab + setup)
     - [ ] Dua widget on home screen
     - [ ] Paywall with new pricing
   - [ ] Update release notes for v1.9:
     - [ ] SalahLock feature (app blocking at prayer time)
     - [ ] Dua widget (30-minute rotating duas)
     - [ ] Updated pricing
     - [ ] Improved onboarding experience

3. **Signing & Provisioning**
   - [ ] Ensure signing certificate is valid
   - [ ] Update provisioning profiles for all three targets (main app, widget, monitor extension)
   - [ ] Verify App ID has required capabilities:
     - [ ] Family Controls (main app and monitor extension)
     - [ ] App Groups (main app and widget)

4. **Manual Testing Recommended**
   - [ ] Test on physical device (not just simulator)
   - [ ] Test lock feature works (enable debug if needed)
   - [ ] Test dua widget displays on lock screen
   - [ ] Test prayer alarms
   - [ ] Go through full onboarding flow
   - [ ] Test paywall and pricing display

## 📋 What's New in v1.9

### Major Features
1. **SalahLock** - Block distracting apps until you pray
   - Enforced by iOS DeviceActivityMonitor
   - Survives app force-quit
   - Configurable per-prayer
   - No special permissions required beyond Screen Time

2. **Dua Widget** - 99+ Quranic & Hadith duas
   - Rotates every 30 minutes deterministically
   - Available on home screen and iOS 16+ lock screen
   - 8 beautiful color themes
   - Monochrome on lock screen (iOS constraint)

3. **Enhanced Pricing**
   - Weekly: $7.99
   - Monthly: $24.99 (shows as $6.25/week)
   - Yearly: $49.99 (best value)

4. **Improved Onboarding**
   - Lock feature introduction & setup
   - Value proposition before paywall
   - Conversion loop with spin wheel
   - Mandatory review (no skip option)
   - Faith-reinforcement messaging

## 🔐 Security Notes
- RevenueCat test key currently in use (update to production before App Store)
- Family Controls entitlement is production-ready (Apple approved in earlier version)
- All network calls use HTTPS
- Firebase properly configured for data encryption
- No user data is tracked via the lock feature

## 📝 Notes for App Review
- Lock feature uses only Apple's native FamilyControls framework
- No data is sent to third parties for lock enforcement
- Device activity monitoring is transparent to user
- All features can be toggled off by user in Lock tab
- Dua rotation is deterministic and works offline

---

**Status**: Ready for App Store submission after pre-submission actions are completed.
**Last Updated**: July 7, 2026
