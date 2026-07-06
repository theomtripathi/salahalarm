//
//  AppConstants.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine

struct AppConstants {
    
    // MARK: - App Information
    struct App {
        static let name = "SALAHALARM"
        static let tagline = "Never miss a prayer again."
        static let groupIdentifier = "group.ramadan-pro.sonn"
    }
    
    // MARK: - Pricing
    struct Pricing {
        static let weekly = "$6.99"
        static let yearly = "$29.99"
        static let discountedYearly = "$29.99"
        static let discountPercentage = 0
    }
    
    // MARK: - Widget
    struct Widget {
        static let kind = "SalahAlarmWidget"
        static let syncThresholdMinutes = 3
    }
    
    // MARK: - Sadaq
    struct Sadaq {
        static let mealCost = 1.0 // $1 = 1 meal
        static let quickDonateAmounts: [Double] = [100, 500, 1000]
        
        // Hardcoded leaderboard (for demo/social proof)
        struct LeaderboardEntry {
            let rank: Int
            let name: String
            let amount: Double
            let meals: Int
            
            static let topContributors: [LeaderboardEntry] = [
                LeaderboardEntry(rank: 1, name: "Anonymous", amount: 9870, meals: 9870),
                LeaderboardEntry(rank: 2, name: "A. Rahman", amount: 7420, meals: 7420),
                LeaderboardEntry(rank: 3, name: "S. Ali", amount: 5180, meals: 5180),
                LeaderboardEntry(rank: 4, name: "Anonymous", amount: 2950, meals: 2950)
            ]
        }
    }
    
    // MARK: - Qibla
    struct Qibla {
        static let makkahLatitude = 21.4225
        static let makkahLongitude = 39.8262
        static let alignmentToleranceDegrees = 5.0 // Degrees tolerance for haptic feedback
    }
    
    // MARK: - UserDefaults Keys
    struct UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isLoggedIn = "isLoggedIn"
        static let userLocation = "userLocation"
        static let selectedFocus = "selectedFocus"
        static let selectedChallenge = "selectedChallenge"
        static let lastReadSurah = "lastReadSurah"
        static let lastReadAyah = "lastReadAyah"
        static let totalDonations = "totalDonations"
        static let isSubscribed = "isSubscribed"
        /// Counts how many times the app has been launched while logged in,
        /// used to show the Sadaq prompt every Nth run when total donations are 0.
        static let sadaqPromptRunCount = "sadaqPromptRunCount"
    }
    
    // MARK: - Notification Identifiers
    struct NotificationIdentifiers {
        static let prayerPrefix = "prayer_"
        static let imsak30Min = "prayer_imsak_30min"
        static let imsak1Min = "prayer_imsak_1min"
        static let maghrib30Min = "prayer_maghrib_30min"
        static let maghrib1Min = "prayer_maghrib_1min"
    }
    
    // MARK: - UI Constants
    struct UI {
        static let fastingProgressRingSize: CGFloat = 200
        static let fastingProgressRingWidth: CGFloat = 12
        static let prayerCardWidth: CGFloat = 80
        static let widgetCardCornerRadius: CGFloat = 12
        static let defaultPadding: CGFloat = 32
    }
}
