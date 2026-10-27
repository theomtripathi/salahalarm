//
//  FirebaseAuthService.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn
import AuthenticationServices

/// Authentication error types
enum AuthErrorType: LocalizedError {
    case userNotFound
    case wrongPassword
    case emailAlreadyInUse
    case invalidEmail
    case weakPassword
    case networkError
    case invalidCredential
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "Account does not exist"
        case .wrongPassword:
            return "Wrong password"
        case .emailAlreadyInUse:
            return "Email already in use"
        case .invalidEmail:
            return "Invalid email address"
        case .weakPassword:
            return "Password must be at least 6 characters"
        case .networkError:
            return "Network error. Please check your connection"
        case .invalidCredential:
            // Covers cases like "supplied auth credential is malformed or has expired"
            // and other low-level credential issues.
            return "Invalid email or password. Please try again."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

/// Service for handling Firebase Authentication
@MainActor
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var appleSignInHelper: AppleSignInHelper?
    
    private init() {
        print("🔧 FirebaseAuthService: Initializing...")
        
        // Listen to authentication state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseAuthUser in
            Task { @MainActor in
                if let firebaseAuthUser = firebaseAuthUser {
                    print("🔄 FirebaseAuthService: Auth state changed - user signed in: \(firebaseAuthUser.uid)")
                    // Set isLoggedIn flag in UserDefaults
                    UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
                    await self?.loadUserData(userId: firebaseAuthUser.uid)
                } else {
                    print("🔄 FirebaseAuthService: Auth state changed - user signed out")
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                    // Clear isLoggedIn flag in UserDefaults
                    UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
                }
            }
        }
        
        // Check if user is already signed in
        if let firebaseAuthUser = Auth.auth().currentUser {
            print("✅ FirebaseAuthService: User already signed in: \(firebaseAuthUser.uid)")
            // Set isLoggedIn flag in UserDefaults
            UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
            Task {
                await loadUserData(userId: firebaseAuthUser.uid)
            }
        } else {
            print("ℹ️ FirebaseAuthService: No user currently signed in")
            // Ensure isLoggedIn flag is false
            UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Sign up with email and password
    func signUp(email: String, password: String, name: String?) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let firebaseUser = result.user
            
            // Update display name if provided
            if let name = name {
                let changeRequest = firebaseUser.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
            }
            
            // Create user document in Firestore
            let appUser = User(
                userId: firebaseUser.uid,
                email: firebaseUser.email,
                name: name ?? firebaseUser.displayName,
                createdAt: Date(),
                lastLoginAt: Date()
            )
            // Mark auth success immediately so onboarding can continue without friction.
            currentUser = appUser
            isAuthenticated = true
            appUser.save()
            UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)

            // Firestore profile bootstrap is important, but should not block auth success.
            do {
                try await saveUserToFirestore(appUser)
                await loadUserData(userId: firebaseUser.uid)
            } catch {
                print("⚠️ FirebaseAuthService: signUp post-auth sync failed (non-fatal): \(error.localizedDescription)")
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        print("🔐 FirebaseAuthService: Starting sign in for email: \(email)")
        isLoading = true
        errorMessage = nil
        
        do {
            print("📡 FirebaseAuthService: Signing in with Firebase Auth...")
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let firebaseUser = result.user
            print("✅ FirebaseAuthService: User signed in successfully: \(firebaseUser.uid)")

            // Mark auth success immediately; profile sync should not block continuation.
            currentUser = User(
                userId: firebaseUser.uid,
                email: firebaseUser.email,
                name: firebaseUser.displayName,
                createdAt: Date(),
                lastLoginAt: Date()
            )
            isAuthenticated = true
            UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)

            // Best-effort profile sync.
            do {
                print("📡 FirebaseAuthService: Updating last login timestamp...")
                try await updateLastLogin(userId: firebaseUser.uid)
                print("✅ FirebaseAuthService: Last login updated")
            } catch {
                print("⚠️ FirebaseAuthService: updateLastLogin failed (non-fatal): \(error.localizedDescription)")
            }

            print("📡 FirebaseAuthService: Loading user data from Firestore...")
            await loadUserData(userId: firebaseUser.uid)
            print("✅ FirebaseAuthService: Sign in completed successfully")
            
            isLoading = false
        } catch let error as NSError {
            isLoading = false
            print("❌ FirebaseAuthService: Sign in failed with NSError - code: \(error.code), domain: \(error.domain)")
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        } catch {
            isLoading = false
            print("❌ FirebaseAuthService: Sign in failed with unknown error: \(error.localizedDescription)")
            let authError = AuthErrorType.unknown(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    /// Sign in with Google
    func signInWithGoogle() async throws {
        print("🔐 FirebaseAuthService: Starting Google Sign-In...")
        isLoading = true
        errorMessage = nil
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "FirebaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase client ID not found"])
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "FirebaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller found"])
        }
        
        // Find the topmost view controller
        var presentingViewController = rootViewController
        while let presented = presentingViewController.presentedViewController {
            presentingViewController = presented
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                throw NSError(domain: "FirebaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token"])
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            print("📡 FirebaseAuthService: Signing in to Firebase with Google credential...")
            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user
            print("✅ FirebaseAuthService: User signed in with Google successfully: \(firebaseUser.uid)")
            
            // Check if this is a new user
            let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false
            
            if isNewUser {
                print("📝 FirebaseAuthService: New user detected, creating user document...")
                // Create user document in Firestore
                let appUser = User(
                    userId: firebaseUser.uid,
                    email: firebaseUser.email,
                    name: firebaseUser.displayName,
                    createdAt: Date(),
                    lastLoginAt: Date()
                )
                
                try await saveUserToFirestore(appUser)
                print("✅ FirebaseAuthService: New user document created")
            } else {
                print("📝 FirebaseAuthService: Existing user, updating last login...")
                try await updateLastLogin(userId: firebaseUser.uid)
            }
            
            // Load user data
            await loadUserData(userId: firebaseUser.uid)
            // Set isLoggedIn flag in UserDefaults
            UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
            
            isLoading = false
            print("✅ FirebaseAuthService: Google Sign-In completed successfully")
        } catch let error as NSError {
            isLoading = false
            print("❌ FirebaseAuthService: Google Sign-In failed with NSError - code: \(error.code), domain: \(error.domain)")
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        } catch {
            isLoading = false
            print("❌ FirebaseAuthService: Google Sign-In failed with unknown error: \(error.localizedDescription)")
            let authError = AuthErrorType.unknown(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    /// Sign in with Apple
    func signInWithApple() async throws {
        print("🔐 FirebaseAuthService: Starting Sign in with Apple...")
        isLoading = true
        errorMessage = nil
        
        let helper = AppleSignInHelper()
        appleSignInHelper = helper
        
        do {
            print("🔐 FirebaseAuthService: Awaiting Apple credential from system...")
            let result = try await helper.performRequest()
            let appleIDCredential = result.credential
            let nonce = result.nonce
            print("🔐 FirebaseAuthService: Apple credential received, user: \(appleIDCredential.user)")
            
            guard let idTokenData = appleIDCredential.identityToken,
                  let idTokenString = String(data: idTokenData, encoding: .utf8) else {
                print("❌ FirebaseAuthService: Apple identity token is nil or invalid")
                throw NSError(domain: "FirebaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to get Apple ID token"])
            }
            print("🔐 FirebaseAuthService: Apple ID token extracted (\(idTokenString.count) chars)")
            
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential.fullName)
            
            print("📡 FirebaseAuthService: Signing in to Firebase with Apple credential...")
            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user
            print("✅ FirebaseAuthService: User signed in with Apple successfully: \(firebaseUser.uid)")
            
            let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false
            
            if isNewUser {
                print("📝 FirebaseAuthService: New user detected, creating user document...")
                let name: String?
                if let fullName = appleIDCredential.fullName {
                    let components = [fullName.givenName, fullName.familyName].compactMap { $0 }
                    name = components.isEmpty ? nil : components.joined(separator: " ")
                } else {
                    name = nil
                }
                let appUser = User(
                    userId: firebaseUser.uid,
                    email: firebaseUser.email,
                    name: name ?? firebaseUser.displayName,
                    createdAt: Date(),
                    lastLoginAt: Date()
                )
                try await saveUserToFirestore(appUser)
                print("✅ FirebaseAuthService: New user document created")
            } else {
                print("📝 FirebaseAuthService: Existing user, updating last login...")
                try await updateLastLogin(userId: firebaseUser.uid)
            }
            
            await loadUserData(userId: firebaseUser.uid)
            UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
            
            isLoading = false
            appleSignInHelper = nil
            print("✅ FirebaseAuthService: Apple Sign-In completed successfully")
        } catch let error as NSError {
            appleSignInHelper = nil
            isLoading = false
            print("❌ FirebaseAuthService: Apple Sign-In failed - code: \(error.code), domain: \(error.domain), message: \(error.localizedDescription)")
            let authError = mapFirebaseError(error)
            errorMessage = authError.errorDescription
            throw authError
        } catch {
            appleSignInHelper = nil
            isLoading = false
            print("❌ FirebaseAuthService: Apple Sign-In failed with unknown error: \(error.localizedDescription), type: \(type(of: error))")
            let authError = AuthErrorType.unknown(error)
            errorMessage = authError.errorDescription
            throw authError
        }
    }
    
    /// Sign out current user
    func signOut() throws {
        // Sign out from Google
        GIDSignIn.sharedInstance.signOut()
        
        // Sign out from Firebase
        try Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
        User.clear() // Clear local user data
        // Clear isLoggedIn flag in UserDefaults
        UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
    }
    
        /// Reset password
        func resetPassword(email: String) async throws {
            print("🔄 FirebaseAuthService: Starting password reset for email: \(email)")
            
            do {
                print("📡 FirebaseAuthService: Sending password reset email...")
                try await Auth.auth().sendPasswordReset(withEmail: email)
                print("✅ FirebaseAuthService: Password reset email sent successfully")
            } catch let error as NSError {
                print("❌ FirebaseAuthService: Password reset failed with NSError - code: \(error.code), domain: \(error.domain)")
                let authError = mapFirebaseError(error)
                throw authError
            } catch {
                print("❌ FirebaseAuthService: Password reset failed with unknown error: \(error.localizedDescription)")
                let authError = AuthErrorType.unknown(error)
                throw authError
            }
        }
        
        /// Delete user account and all associated data
        /// Note: May require re-authentication if user hasn't logged in recently
        func deleteAccount(password: String? = nil) async throws {
            print("🗑️ FirebaseAuthService: Starting account deletion...")
            
            guard let user = Auth.auth().currentUser else {
                print("❌ FirebaseAuthService: No authenticated user to delete")
                throw NSError(domain: "FirebaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            }
            
            let userId = user.uid
            var firestoreDataDeleted = false
            
            do {
                // Step 1: Re-authenticate if password provided (for recent authentication requirement)
                // Do this FIRST before deleting Firestore data, so we can fail gracefully if password is wrong
                if let password = password, let email = user.email {
                    print("🔐 FirebaseAuthService: Re-authenticating user before account deletion...")
                    do {
                        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                        try await user.reauthenticate(with: credential)
                        print("✅ FirebaseAuthService: User re-authenticated successfully")
                    } catch {
                        print("❌ FirebaseAuthService: Re-authentication failed: \(error.localizedDescription)")
                        // Re-throw authentication errors immediately without deleting Firestore data
                        if let nsError = error as? NSError {
                            if let authErrorCode = AuthErrorCode(rawValue: nsError.code) {
                                switch authErrorCode {
                                case .wrongPassword:
                                    throw NSError(domain: "FirebaseAuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "Wrong password. Please try again."])
                                case .invalidEmail, .invalidCredential:
                                    throw NSError(domain: "FirebaseAuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials. Please check your password and try again."])
                                default:
                                    throw NSError(domain: "FirebaseAuthService", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "Authentication failed: \(error.localizedDescription)"])
                                }
                            }
                        }
                        throw error
                    }
                }
                
                // Step 2: Delete all user data from Firestore
                print("🗑️ FirebaseAuthService: Deleting user data from Firestore...")
                try await deleteUserData(userId: userId)
                firestoreDataDeleted = true
                print("✅ FirebaseAuthService: User data deleted from Firestore")
                
                // Step 3: Delete Firebase Auth account
                print("🗑️ FirebaseAuthService: Deleting Firebase Auth account...")
                try await user.delete()
                print("✅ FirebaseAuthService: Firebase Auth account deleted")
                
                // Step 4: Clear local state
                currentUser = nil
                isAuthenticated = false
                User.clear()
                print("✅ FirebaseAuthService: Account deletion completed successfully")
            } catch let error as NSError {
                print("❌ FirebaseAuthService: Account deletion failed with NSError - code: \(error.code), domain: \(error.domain)")
                
                // Check if it's a recent login required error (and we haven't deleted Firestore data yet)
                if let authErrorCode = AuthErrorCode(rawValue: error.code) {
                    if authErrorCode == .requiresRecentLogin && !firestoreDataDeleted {
                        print("⚠️ FirebaseAuthService: Account deletion requires recent authentication")
                        throw NSError(domain: "FirebaseAuthService", code: error.code, userInfo: [NSLocalizedDescriptionKey: "This operation requires recent authentication. Please provide your password to continue."])
                    }
                    
                    // If Firestore data was already deleted but auth deletion failed, 
                    // still clear local state and consider it successful (data is already gone)
                    if firestoreDataDeleted && authErrorCode == .requiresRecentLogin {
                        print("⚠️ FirebaseAuthService: Firestore data deleted but auth account deletion requires re-auth")
                        print("⚠️ FirebaseAuthService: Clearing local state anyway since Firestore data is already deleted")
                        currentUser = nil
                        isAuthenticated = false
                        User.clear()
                        // Don't throw error - consider it successful since data is deleted
                        return
                    }
                }
                
                // If we already deleted Firestore data, consider deletion successful even if auth deletion has issues
                // (The user data is already gone from Firestore)
                if firestoreDataDeleted {
                    print("⚠️ FirebaseAuthService: Firestore data was deleted. Clearing local state...")
                    currentUser = nil
                    isAuthenticated = false
                    User.clear()
                    // Return successfully - the important data is already deleted
                    print("✅ FirebaseAuthService: Account deletion completed (Firestore data deleted, auth status cleared)")
                    return
                }
                
                let authError = mapFirebaseError(error)
                throw authError
            } catch {
                // If Firestore data was already deleted, consider it successful
                if firestoreDataDeleted {
                    print("⚠️ FirebaseAuthService: Firestore data was deleted. Clearing local state...")
                    currentUser = nil
                    isAuthenticated = false
                    User.clear()
                    print("✅ FirebaseAuthService: Account deletion completed (Firestore data deleted, auth status cleared)")
                    return
                }
                
                print("❌ FirebaseAuthService: Account deletion failed with unknown error: \(error.localizedDescription)")
                let authError = AuthErrorType.unknown(error)
                throw authError
            }
        }
        
        /// Delete all user data from Firestore
        private func deleteUserData(userId: String) async throws {
            print("🗑️ FirebaseAuthService: Deleting all data for user \(userId)...")
            
            // Delete user document
            try await db.collection("users").document(userId).delete()
            print("✅ FirebaseAuthService: User document deleted")
            
            // Delete all bookmarks
            let bookmarksSnapshot = try await db.collection("bookmarks")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            for document in bookmarksSnapshot.documents {
                try await document.reference.delete()
            }
            print("✅ FirebaseAuthService: Deleted \(bookmarksSnapshot.documents.count) bookmarks")
            
            print("✅ FirebaseAuthService: All user data deleted successfully")
        }
    
    // MARK: - Error Mapping
    
    /// Map Firebase Auth error codes to user-friendly error types
    private func mapFirebaseError(_ error: NSError) -> AuthErrorType {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            print("❌ FirebaseAuthService: Unknown error code: \(error.code), message: \(error.localizedDescription)")
            return .unknown(error)
        }
        
        print("🔍 FirebaseAuthService: Mapping error code: \(errorCode.rawValue), description: \(error.localizedDescription)")
        
        switch errorCode {
        case .userNotFound:
            print("❌ FirebaseAuthService: User not found")
            return .userNotFound
        case .wrongPassword:
            print("❌ FirebaseAuthService: Wrong password")
            return .wrongPassword
        case .invalidCredential:
            print("❌ FirebaseAuthService: Invalid credential (malformed or expired)")
            return .invalidCredential
        case .emailAlreadyInUse:
            print("❌ FirebaseAuthService: Email already in use")
            return .emailAlreadyInUse
        case .invalidEmail:
            print("❌ FirebaseAuthService: Invalid email")
            return .invalidEmail
        case .weakPassword:
            print("❌ FirebaseAuthService: Weak password")
            return .weakPassword
        case .networkError:
            print("❌ FirebaseAuthService: Network error")
            return .networkError
        default:
            print("❌ FirebaseAuthService: Unhandled error code: \(errorCode.rawValue)")
            return .unknown(error)
        }
    }
    
    // MARK: - User Data Methods
    
    /// Load user data from Firestore
    private func loadUserData(userId: String) async {
        print("📡 FirebaseAuthService: Loading user data for userId: \(userId)")
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists, let data = document.data() {
                print("✅ FirebaseAuthService: User document found in Firestore")
                let user = try decodeUser(from: data, userId: userId)
                self.currentUser = user
                self.isAuthenticated = true
                user.save() // Save to local storage
                // Set isLoggedIn flag in UserDefaults
                UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
                // Save subscription status to UserDefaults for quick access
                UserDefaults.standard.set(user.isSubscribed, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                WidgetConfig.saveDisplayName(user.name ?? "")
                print("✅ FirebaseAuthService: User data loaded and saved locally")
                print("💾 FirebaseAuthService: Subscription status saved to UserDefaults: \(user.isSubscribed)")
            } else {
                // If user document doesn't exist, create it
                print("⚠️ FirebaseAuthService: User document not found, creating new document...")
                if let firebaseAuthUser = Auth.auth().currentUser {
                    let appUser = User(
                        userId: firebaseAuthUser.uid,
                        email: firebaseAuthUser.email,
                        name: firebaseAuthUser.displayName,
                        createdAt: Date(),
                        lastLoginAt: Date()
                    )
                    try await saveUserToFirestore(appUser)
                    self.currentUser = appUser
                    self.isAuthenticated = true
                    appUser.save()
                    // Set isLoggedIn flag in UserDefaults
                    UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
                    // New user has no subscription
                    UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                    WidgetConfig.saveDisplayName(appUser.name ?? "")
                    print("✅ FirebaseAuthService: New user document created and saved")
                }
            }
        } catch {
            print("❌ FirebaseAuthService: Error loading user data: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Reload user data from Firestore (public method for external services)
    func reloadUserData() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ FirebaseAuthService: No authenticated user to reload")
            return
        }
        await loadUserData(userId: userId)
    }
    
    /// Encode SubscriptionStatus to Firestore format
    private func encodeSubscriptionStatus(_ status: SubscriptionStatus) -> [String: Any] {
        var dict: [String: Any] = [
            "isActive": status.isActive,
            "autoRenew": status.autoRenew,
            "isInTrial": false
        ]
        
        if let planType = status.planType {
            dict["planType"] = planType.rawValue
        }
        if let startDate = status.startDate {
            dict["startDate"] = Timestamp(date: startDate)
        }
        if let expiryDate = status.expiryDate {
            dict["expiryDate"] = Timestamp(date: expiryDate)
        }
        if let cancelledDate = status.cancelledDate {
            dict["cancelledDate"] = Timestamp(date: cancelledDate)
        }
        dict["trialEndDate"] = NSNull()
        
        return dict
    }
    
    /// Save user to Firestore
    private func saveUserToFirestore(_ appUser: User) async throws {
        let userData: [String: Any] = [
            "userId": appUser.userId,
            "email": appUser.email ?? "",
            "name": appUser.name ?? "",
            "createdAt": Timestamp(date: appUser.createdAt),
            "lastLoginAt": appUser.lastLoginAt != nil ? Timestamp(date: appUser.lastLoginAt!) : NSNull(),
            "subscriptionStatus": appUser.subscriptionStatus != nil ? encodeSubscriptionStatus(appUser.subscriptionStatus!) : [:]
        ]
        
        try await db.collection("users").document(appUser.userId).setData(userData, merge: true)
    }
    
    /// Update last login timestamp
    private func updateLastLogin(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "lastLoginAt": Timestamp(date: Date())
        ])
    }
    
    /// Decode User from Firestore data
    private func decodeUser(from data: [String: Any], userId: String) throws -> User {
        let email = data["email"] as? String
        let name = data["name"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let lastLoginAt = (data["lastLoginAt"] as? Timestamp)?.dateValue()
        
        // Decode subscription status
        // Check for new structure: subscriptionStatus (boolean) + subscriptionDetails (object)
        var subscriptionStatus: SubscriptionStatus?
        
        // First, check if subscriptionStatus is a boolean (new structure)
        if let isActiveBool = data["subscriptionStatus"] as? Bool, isActiveBool {
            // New structure: subscriptionStatus is true, details are in subscriptionDetails
            if let subscriptionDetails = data["subscriptionDetails"] as? [String: Any] {
                print("📊 FirebaseAuthService: Found subscriptionDetails object")
                let planTypeString = subscriptionDetails["planType"] as? String
                let planType = planTypeString != nil ? SubscriptionPlanType(rawValue: planTypeString!) : nil
                let startDate = (subscriptionDetails["startDate"] as? Timestamp)?.dateValue()
                let expiryDate = (subscriptionDetails["endDate"] as? Timestamp)?.dateValue() ?? (subscriptionDetails["expiryDate"] as? Timestamp)?.dateValue()
                let autoRenew = subscriptionDetails["autoRenew"] as? Bool ?? true
                let cancelledDate = (subscriptionDetails["cancelledDate"] as? Timestamp)?.dateValue()
                subscriptionStatus = SubscriptionStatus(
                    isActive: true,
                    planType: planType,
                    startDate: startDate,
                    expiryDate: expiryDate,
                    autoRenew: autoRenew,
                    cancelledDate: cancelledDate,
                    trialEndDate: nil,
                    isInTrial: false
                )
                print("✅ FirebaseAuthService: Decoded subscriptionDetails - Plan: \(planType?.rawValue ?? "none"), Start: \(startDate?.description ?? "none"), End: \(expiryDate?.description ?? "none")")
            } else {
                // subscriptionStatus is true but no subscriptionDetails - create minimal status
                print("⚠️ FirebaseAuthService: subscriptionStatus is true but subscriptionDetails not found")
                subscriptionStatus = SubscriptionStatus(isActive: true)
            }
        } else if let subscriptionData = data["subscriptionStatus"] as? [String: Any] {
            // Old structure: subscriptionStatus is an object
            print("📊 FirebaseAuthService: Found old subscriptionStatus object structure")
            let isActive = subscriptionData["isActive"] as? Bool ?? false
            let planTypeString = subscriptionData["planType"] as? String
            let planType = planTypeString != nil ? SubscriptionPlanType(rawValue: planTypeString!) : nil
            let startDate = (subscriptionData["startDate"] as? Timestamp)?.dateValue()
            let expiryDate = (subscriptionData["expiryDate"] as? Timestamp)?.dateValue()
            let autoRenew = subscriptionData["autoRenew"] as? Bool ?? true
            let cancelledDate = (subscriptionData["cancelledDate"] as? Timestamp)?.dateValue()
            subscriptionStatus = SubscriptionStatus(
                isActive: isActive,
                planType: planType,
                startDate: startDate,
                expiryDate: expiryDate,
                autoRenew: autoRenew,
                cancelledDate: cancelledDate,
                trialEndDate: nil,
                isInTrial: false
            )
        }
        
        let appUser = User(
            userId: userId,
            email: email,
            name: name,
            createdAt: createdAt,
            lastLoginAt: lastLoginAt,
            subscriptionStatus: subscriptionStatus
        )
        
        return appUser
    }
    
    /// Update user profile
    func updateProfile(name: String?) async throws {
        guard let currentUser = currentUser else {
            throw NSError(domain: "FirebaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        
        // Update Firebase Auth display name
        if let firebaseAuthUser = Auth.auth().currentUser, let name = name {
            let changeRequest = firebaseAuthUser.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
        }
        
        // Update Firestore
        var updateData: [String: Any] = [:]
        if let name = name {
            updateData["name"] = name
        }
        
        if !updateData.isEmpty {
            try await db.collection("users").document(currentUser.userId).updateData(updateData)
            await loadUserData(userId: currentUser.userId) // Reload user data
        }
    }

    func mergeOnboardingPayload(profile: OnboardingProfile, plan: OnboardingDerivedPlan) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let profileData = OnboardingPersistenceService.encodeProfile(profile)
        let planData = OnboardingPersistenceService.encodePlan(plan)

        do {
            try await db.collection("users").document(userId).setData([
                "onboardingProfile": profileData,
                "onboardingDerivedPlan": planData,
                "onboardingLastScreen": profile.lastCompletedScreen,
                "onboardingCompletedAt": profile.onboardingCompletedAt as Any
            ], merge: true)
        } catch {
            print("⚠️ FirebaseAuthService: Failed to merge onboarding payload - \(error.localizedDescription)")
        }
    }
}
