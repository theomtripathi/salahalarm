//
//  LogoutService.swift
//  Ramadan Pro
//
//  Created by Cursor on 2026-01-24.
//

import Foundation
import RevenueCat

/// Clears all app data on logout: UserDefaults (standard + app group), RevenueCat,
/// onboarding state, in-memory view models, navigation, then signs out from Firebase/Google.
@MainActor
enum LogoutService {

    /// All UserDefaults keys we persist (standard container).
    private static let standardKeys: [String] = [
        "current_user",
        "user_preferences",
        "quran_bookmarks",
        "last_read_quran",
        "subscription_status",
        "saved_user_location",
        "hasCompletedOnboarding",
        "paywallViewCount",
        "salahlock_streak_data",
        AppConstants.UserDefaultsKeys.isLoggedIn,
        AppConstants.UserDefaultsKeys.userLocation,
        AppConstants.UserDefaultsKeys.selectedFocus,
        AppConstants.UserDefaultsKeys.selectedChallenge,
        AppConstants.UserDefaultsKeys.lastReadSurah,
        AppConstants.UserDefaultsKeys.lastReadAyah,
        AppConstants.UserDefaultsKeys.isSubscribed,
    ]

    /// Clear all local app data (UserDefaults, onboarding, RevenueCat, navigation, widget).
    /// Does not sign out from Firebase. Use after account deletion or from logout before signOut.
    static func clearAllLocalState() async {
        // 1. Clear standard UserDefaults
        let defaults = UserDefaults.standard
        for key in standardKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()

        // 2. Clear App Group UserDefaults (widget)
        if let shared = UserDefaults(suiteName: WidgetConfig.appGroupIdentifier) {
            shared.removeObject(forKey: WidgetConfig.userLocationKey)
            shared.removeObject(forKey: WidgetConfig.isSubscribedKey)
            shared.removeObject(forKey: WidgetConfig.streakDataKey)
            shared.removeObject(forKey: WidgetConfig.displayNameKey)
            shared.synchronize()
        }

        // 3. Reset onboarding state
        let onboarding = OnboardingState.shared
        onboarding.hasCompletedOnboarding = false
        onboarding.resetPaywallTracking()
        onboarding.currentStep = .login

        // 4. RevenueCat: log out and reset local state
        do {
            _ = try await Purchases.shared.logOut()
        } catch {
            print("⚠️ LogoutService: RevenueCat logOut failed: \(error.localizedDescription)")
        }
        RevenueCatService.shared.clearSubscriptionState()

        // 5. In-memory: Quran bookmarks & last read
        QuranViewModel.shared.clearLocalData()

        // 6. Navigation: dismiss sheet, close side menu, clear paths
        let nav = NavigationCoordinator.shared
        nav.dismissSheet()
        nav.dismissFullScreenCover()
        nav.clearAllPaths()

        AppState.shared.isSideMenuOpen = false

        // 7. Reload widget so it reflects cleared data
        WidgetHelper.reloadAllWidgets()

        print("✅ LogoutService: All local app data cleared")
    }

    /// Clear all app data and sign out. Call from logout UI (sidebar, profile sheet, etc.).
    static func clearAllAndSignOut() async throws {
        await clearAllLocalState()
        try FirebaseAuthService.shared.signOut()
        print("✅ LogoutService: User signed out")
    }
}
