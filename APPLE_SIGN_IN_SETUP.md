# Sign in with Apple – Setup Guide

This guide walks you through adding Sign in with Apple to Ramadan Pro.

---

## Step 1: Enable Sign in with Apple

> **Required:** Sign in with Apple needs a **paid Apple Developer account** ($99/year). If you use a free/personal team, the capability will not appear in Xcode.

### Option A: Add via Xcode (recommended)

1. Open the project in Xcode
2. Select the **Ramadan Pro** target
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Search for **Sign in with Apple** (scroll down if needed – it may be near the bottom)
6. Double-click to add it

### Option B: Enable in Apple Developer Portal first (if it doesn’t show in Xcode)

1. Go to [developer.apple.com](https://developer.apple.com) → **Account** → **Certificates, Identifiers & Profiles**
2. Under **Identifiers**, select your App ID (e.g. `com.Ramadan-Pro` or your bundle ID)
3. Enable **Sign in with Apple**
4. Click **Save**
5. In Xcode, try adding the capability again – it may appear after a refresh or reopening the project

### Still not showing?

- Ensure you’re signed in with a **paid** Apple Developer account in Xcode (Xcode → Settings → Accounts)
- Check that your team is set to your paid developer team, not “Personal Team”
- Close and reopen Xcode after enabling it in the Developer Portal

---

## Step 2: Enable Apple in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Open **Authentication** → **Sign-in method**
4. Click **Apple**
5. Turn on **Enable**
6. For native iOS apps, you can leave the Service ID and OAuth fields empty
7. Click **Save**

---

## Step 3: Code Implementation (Already Done)

The following are already implemented in the project:

- **FirebaseAuthService.signInWithApple()** – Apple auth flow and Firebase sign-in
- **AuthViewModel.signInWithApple()** – ViewModel wrapper
- **AppleSignInButton** – UI component styled like the Google button
- **LoginView** and **SignUpView** – Apple button added above Google

---

## Step 4: Test Sign in with Apple

1. Build and run on a **physical device** (Sign in with Apple does not work in Simulator)
2. Go to the Login or Sign Up screen
3. Tap **Continue with Apple**
4. Complete the Apple ID flow
5. You should be signed in and moved to the next onboarding step

---

## Requirements

- **Physical device** – Sign in with Apple is not supported in the iOS Simulator
- **Apple ID with 2FA** – User must have two-factor authentication enabled
- **iCloud signed in** – User must be signed into iCloud on the device

---

## Troubleshooting

### "Sign in with Apple is not supported"
- Run on a real device, not the Simulator

### "Invalid state: A login callback was received, but no login request was sent"
- Nonce handling issue – ensure the nonce is stored and passed correctly
- Check that `currentNonce` is set before starting the flow

### App stuck after entering password and tapping Sign In
- **Code fix applied**: The helper is now explicitly retained and delegate callbacks run on the main thread
- **Check Xcode console**: Run the app from Xcode and watch for these logs in order:
  1. `🔐 FirebaseAuthService: Starting Sign in with Apple...`
  2. `🍎 AppleSignInHelper: Generating nonce and creating request...`
  3. `🍎 AppleSignInHelper: Presenting Sign in with Apple sheet...`
  4. *(User interacts with Apple sheet)*
  5. `🍎 AppleSignInHelper: User completed Apple authorization (delegate callback received)`
  6. `✅ AppleSignInHelper: Got credential - user: ..., hasIdentityToken: true`
  7. `🔐 FirebaseAuthService: Apple credential received...`
  8. `📡 FirebaseAuthService: Signing in to Firebase with Apple credential...`
  9. `✅ FirebaseAuthService: Apple Sign-In completed successfully`
- **Where it stops**: If logs stop at step 5, the delegate callback never fired (retention/thread issue). If they stop at step 8, Firebase is failing—check Apple provider is enabled in Firebase Console
- **Firebase configuration**: Ensure Apple is enabled in Firebase Console → Authentication → Sign-in method
- **Physical device**: Sign in with Apple must be tested on a real device, not Simulator

### Capability missing or not showing in Xcode
- **Paid account required** – Sign in with Apple needs a paid Apple Developer account ($99/year). Free/personal teams do not get this capability
- Enable it in [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list) → Identifiers → your App ID → enable "Sign in with Apple" first, then try adding in Xcode again
- Ensure "Sign in with Apple" is added under Signing & Capabilities for the Ramadan Pro target
