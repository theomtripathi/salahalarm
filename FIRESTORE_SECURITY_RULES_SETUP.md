# Firestore Security Rules Setup

This document explains how to set up Firestore security rules for the Ramadan Pro app to allow donations and other features to work properly.

## ❌ Error: "Missing or insufficient permissions"

If you're seeing this error when trying to make a donation, it means your Firestore security rules are not configured correctly.

## 🔧 Setup Instructions

### Step 1: Open Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click on **Firestore Database** in the left sidebar
4. Click on the **Rules** tab

### Step 2: Copy the Security Rules

Copy the rules from `firestore.rules` file in this project, or use the rules below:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the resource
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      // Users can read their own data
      allow read: if isOwner(userId);
      
      // Users can write their own data (for impact updates)
      allow write: if isOwner(userId);
      
      // Allow authenticated users to update their impact field
      allow update: if isAuthenticated() && 
                       request.auth.uid == userId &&
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['impact']);
    }
    
    // Donations collection
    match /donations/{donationId} {
      // Users can create their own donations
      allow create: if isAuthenticated() && 
                       request.resource.data.userId == request.auth.uid;
      
      // Users can read their own donations
      allow read: if isAuthenticated() && 
                     resource.data.userId == request.auth.uid;
      
      // Users can update their own donations (if needed)
      allow update: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid;
      
      // Users can delete their own donations (if needed)
      allow delete: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid;
    }
    
    // Leaderboard collection
    match /leaderboard/{userId} {
      // Anyone can read the leaderboard (public)
      allow read: if true;
      
      // Users can create/update their own leaderboard entry
      allow write: if isAuthenticated() && 
                      (request.resource.data.userId == request.auth.uid || 
                       resource == null || 
                       resource.data.userId == request.auth.uid);
    }
    
    // Default: deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 3: Paste and Publish

1. Paste the rules into the Firebase Console Rules editor
2. Click **Publish** to save the rules
3. Wait a few seconds for the rules to propagate

## 📋 What These Rules Do

### Users Collection
- ✅ Authenticated users can read their own user document
- ✅ Authenticated users can update their own user document (for impact updates)
- ✅ Users can only modify their own data

### Donations Collection
- ✅ Authenticated users can create donations (with their own userId)
- ✅ Users can read only their own donations
- ✅ Users can update/delete only their own donations
- ❌ Users cannot create donations for other users
- ❌ Users cannot read other users' donations

### Leaderboard Collection
- ✅ Anyone can read the leaderboard (public)
- ✅ Authenticated users can create/update their own leaderboard entry
- ✅ Users can only modify their own leaderboard entry

## 🔒 Security Features

1. **Authentication Required**: All write operations require the user to be authenticated
2. **User Ownership**: Users can only access/modify their own data
3. **Data Validation**: Donations must have the correct userId matching the authenticated user
4. **Public Read for Leaderboard**: Leaderboard is readable by everyone (for display purposes)

## 🧪 Testing

After updating the rules:

1. Make sure you're logged in to the app
2. Try making a donation (e.g., $500)
3. The donation should save successfully without permission errors
4. Check Firebase Console → Firestore Database to verify the donation was saved

## ⚠️ Important Notes

1. **Rules Propagation**: After publishing, rules may take a few seconds to propagate
2. **Development Mode**: If you're in development, you might have more permissive rules. Make sure to use production rules before going live
3. **User Authentication**: Make sure users are properly authenticated before attempting donations
4. **Testing**: Always test with a real authenticated user, not in development mode with open rules

## 🐛 Troubleshooting

### Still getting permission errors?

1. **Check Authentication**: Make sure the user is logged in
   ```swift
   // In your code, verify:
   guard let userId = Auth.auth().currentUser?.uid else {
       // User not authenticated
   }
   ```

2. **Check Rules Status**: In Firebase Console → Firestore → Rules, verify the rules are published

3. **Check User ID Match**: Ensure the `userId` in the donation matches `request.auth.uid`

4. **Check Collection Names**: Verify collection names match:
   - `donations` (not `donation`)
   - `users` (not `user`)
   - `leaderboard` (not `leaderboards`)

5. **Clear App Data**: Sometimes cached permissions can cause issues. Try:
   - Logging out and logging back in
   - Clearing app data
   - Reinstalling the app

## 📚 Resources

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
