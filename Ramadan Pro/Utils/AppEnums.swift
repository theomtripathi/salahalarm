//
//  AppEnums.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation

/// Tab navigation items
enum TabItem: Int, CaseIterable {
    case home = 0
    case prayers = 1
    case quran = 2
    case qibla = 3
    case profile = 4
}

/// Focus options for onboarding
enum FocusOption: String, CaseIterable {
    case prayer = "Prayer"
    case quran = "Quran"
    case charity = "Charity"
}

/// Challenge options for onboarding
enum ChallengeOption: String, CaseIterable {
    case forget = "I forget"
    case busySchedule = "Busy schedule"
    case noStructure = "No structure"
    case lowMotivation = "Low motivation"
}

/// Subscription plan types
enum SubscriptionPlan: String, CaseIterable {
    case weekly = "Weekly"
    case yearly = "Yearly"

    static var allCases: [SubscriptionPlan] {
        [.weekly, .yearly]
    }
    
    var price: String {
        switch self {
        case .weekly: return "\(AppConstants.Pricing.weekly) / week"
        case .yearly: return "\(AppConstants.Pricing.yearly) / year"
        }
    }
    
    var isBestValue: Bool {
        return self == .yearly
    }
}

/// Centralized enums for the entire application
enum AppEnums {
    /// Represents the main tabs in the application
    enum TabItem: Int, CaseIterable, Identifiable {
        case home = 0
        case prayers = 1
        case quran = 2
        case qibla = 3
        case profile = 4
        
        var id: Int { self.rawValue }
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .prayers: return "Prayers"
            case .quran: return "Quran"
            case .qibla: return "Qibla"
            case .profile: return "Profile"
            }
        }
        
        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .prayers: return "sun.max.fill"
            case .quran: return "book.fill"
            case .qibla: return "location.north.fill"
            case .profile: return "person.fill"
            }
        }
    }
    
    /// Navigation routes for the app
    enum NavigationRoute: Hashable {
        case quranReading(surah: String? = nil, juz: Int? = nil, page: Int? = nil)
        case prayerDetail(prayerType: String)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .quranReading(let surah, let juz, let page):
                hasher.combine("quranReading")
                hasher.combine(surah)
                hasher.combine(juz)
                hasher.combine(page)
            case .prayerDetail(let prayerType):
                hasher.combine("prayerDetail")
                hasher.combine(prayerType)
            }
        }
        
        static func == (lhs: NavigationRoute, rhs: NavigationRoute) -> Bool {
            switch (lhs, rhs) {
            case (.quranReading(let surah1, let juz1, let page1), .quranReading(let surah2, let juz2, let page2)):
                return surah1 == surah2 && juz1 == juz2 && page1 == page2
            case (.prayerDetail(let type1), .prayerDetail(let type2)):
                return type1 == type2
            default: return false
            }
        }
    }
    
    /// Sheets that can be presented (currently unused - all removed)
    enum PresentedSheet: Identifiable {
        // All sheet cases have been removed - sidebar no longer uses sheets
        
        var id: String {
            return "empty"
        }
    }
    
    /// Full screen covers that can be presented
    enum PresentedFullScreenCover: Identifiable {
        case onboarding
        case paywall
        
        var id: String {
            switch self {
            case .onboarding: return "onboarding"
            case .paywall: return "paywall"
            }
        }
    }
}
