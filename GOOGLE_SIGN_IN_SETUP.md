# Google Sign-In Setup Guide

This guide will help you set up Google Sign-In for your Ramadan Pro app.

## Prerequisites
- Firebase project already configured
- `GoogleService-Info.plist` file already added to the project

## Step 1: Enable Google Sign-In in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **ramadan-pro-684da**
3. Navigate to **Authentication** → **Sign-in method**
4. Find **Google** in the providers list
5. Click on **Google** and enable it
6. Enter your **Support email** (e.g., support@yourdomain.com)
7. Select your **Project support email** from the dropdown
8. Click **Save**

## Step 2: Add Google Sign-In SDK to Xcode Project

1. Open your Xcode project
2. Go to **File** → **Add Package Dependencies...**
3. Enter the package URL: `https://github.com/google/GoogleSignIn-iOS`
4. Select version: **7.0.0** or latest
5. Click **Add Package**
6. Select the following products:
   - **GoogleSignIn**
   - **GoogleSignInSwift** (optional, provides SwiftUI helpers)
7. Click **Add Package**

## Step 3: Configure URL Scheme in Xcode

1. In Xcode, select your project in the navigator
2. Select the **Ramadan Pro** target
3. Go to **Info** tab
4. Expand **URL Types**
5. Click **+** to add a new URL Type
6. Enter:
   - **Identifier**: `com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID`
   - **URL Schemes**: The **REVERSED_CLIENT_ID** from your `GoogleService-Info.plist`
   
   To find the REVERSED_CLIENT_ID:
   - Open `GoogleService-Info.plist`
   - Find the key `REVERSED_CLIENT_ID`
   - Copy its value (it should look like: `com.googleusercontent.apps.XXXXXXXXXX`)
   - Paste it in the **URL Schemes** field (without the `com.googleusercontent.apps.` prefix)

7. Save the project

## Step 4: Update Info.plist (if needed)

The URL scheme configuration should be sufficient, but if needed:

1. Open `Ramadan-Pro-Info.plist`
2. Add or verify the URL scheme exists under `CFBundleURLTypes`

## Step 5: Verify GoogleService-Info.plist

Make sure your `GoogleService-Info.plist` contains:
- `CLIENT_ID`
- `REVERSED_CLIENT_ID`
- `BUNDLE_ID` matches your app's bundle ID

## Step 6: Test Google Sign-In

1. Build and run your app
2. Navigate to the Sign Up screen
3. Click **"Sign up with Google"** button
4. You should see Google's sign-in flow
5. After successful sign-in, the app should proceed to onboarding

## Troubleshooting

### Error: "Firebase client ID not found"
- Make sure `GoogleService-Info.plist` is added to the target
- Verify `FirebaseApp.configure()` is called before using Google Sign-In

### Error: "No presenting view controller found"
- Make sure the app window is fully loaded before calling sign-in

### Google Sign-In doesn't open
- Verify URL scheme is correctly configured
- Check that `REVERSED_CLIENT_ID` matches exactly
- Make sure Google Sign-In is enabled in Firebase Console

### App crashes on Google Sign-In
- Ensure Google Sign-In SDK is properly linked
- Check that all required frameworks are included

## Additional Notes

- The Google Sign-In button is placed under "Join us to track your Ramadan journey" text
- After successful Google Sign-In, users will automatically proceed to onboarding flow
- User data (name, email) from Google account will be saved to Firestore
- The app supports both new users (signup) and existing users (login) via Google
