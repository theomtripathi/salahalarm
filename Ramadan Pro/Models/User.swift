//
//  User.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine

/// User model representing app user
struct User: Codable {
    let userId: String
    let email: String?
    let name: String?
    let createdAt: Date
    let lastLoginAt: Date?
    let subscriptionStatus: SubscriptionStatus?
    
    init(userId: String,
         email: String? = nil,
         name: String? = nil,
         createdAt: Date = Date(),
         lastLoginAt: Date? = nil,
         subscriptionStatus: SubscriptionStatus? = nil) {
        self.userId = userId
        self.email = email
        self.name = name
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.subscriptionStatus = subscriptionStatus
    }
    
    /// Save to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "current_user")
        }
    }
    
    /// Load from UserDefaults
    static func load() -> User? {
        guard let data = UserDefaults.standard.data(forKey: "current_user"),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }
    
    /// Clear user data (on logout)
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "current_user")
    }
    
    // MARK: - Subscription Helpers
    
    /// Check if user has an active subscription
    var isSubscribed: Bool {
        #if DEBUG
        // TEST: Special email for testing - always considered subscribed (DEBUG builds only)
        if let email = email, email.lowercased() == "bansalbansal511@gmail.com" {
            print("✅ User: Test email detected (\(email)) - granting subscription access (DEBUG only)")
            return true
        }
        #endif
        
        guard let status = subscriptionStatus else { return false }
        return status.isActive && !status.isExpired
    }
    
    /// Get subscription start date
    var subscriptionStartDate: Date? {
        return subscriptionStatus?.startDate
    }
    
    /// Get subscription end date
    var subscriptionEndDate: Date? {
        return subscriptionStatus?.expiryDate
    }
    
    /// Get subscription plan type
    var subscriptionPlanType: SubscriptionPlanType? {
        return subscriptionStatus?.planType
    }
}

/// User preferences and settings
struct UserPreferences: Codable {
    let language: String // Language code (e.g., "en", "ar")
    let prayerTimeMethod: String? // Calculation method preference
    let notificationsEnabled: Bool
    let prayerNotificationsEnabled: Bool
    let soundEnabled: Bool
    let hapticFeedbackEnabled: Bool
    let darkModeEnabled: Bool
    
    init(language: String = "en",
         prayerTimeMethod: String? = nil,
         notificationsEnabled: Bool = true,
         prayerNotificationsEnabled: Bool = true,
         soundEnabled: Bool = true,
         hapticFeedbackEnabled: Bool = true,
         darkModeEnabled: Bool = false) {
        self.language = language
        self.prayerTimeMethod = prayerTimeMethod
        self.notificationsEnabled = notificationsEnabled
        self.prayerNotificationsEnabled = prayerNotificationsEnabled
        self.soundEnabled = soundEnabled
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.darkModeEnabled = darkModeEnabled
    }
    
    /// Save to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "user_preferences")
        }
    }
    
    /// Load from UserDefaults
    static func load() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: "user_preferences"),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences() // Return default preferences if not found
        }
        return preferences
    }
}

/// User API response
struct UserAPIResponse: Codable {
    let success: Bool
    let user: User?
    let message: String?
    let error: String?
}

/// Login/Register API response
struct AuthAPIResponse: Codable {
    let success: Bool
    let user: User?
    let token: String?
    let refreshToken: String?
    let message: String?
    let error: String?
}
