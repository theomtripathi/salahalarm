//
//  AppState.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import SwiftUI
import Combine

/// Global app state for navigation and shared data
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var selectedTab: Int = 0
    @Published var selectedPrayerType: String?
    @Published var isSideMenuOpen: Bool = false
    @Published var shouldExitOnboarding: Bool = false
    @Published var onboardingComplete: Bool {
        didSet {
            UserDefaults.standard.set(onboardingComplete, forKey: "sl_onboarding_complete")
        }
    }
    @Published var shouldShowSadaqPrompt: Bool = false
    @Published var isGuest: Bool {
        didSet {
            UserDefaults.standard.set(isGuest, forKey: AppConstants.UserDefaultsKeys.isGuest)
        }
    }
    /// True after someone buys before creating an account, until they sign up or sign in.
    /// RootRouterView keeps them on the account screen so the purchase is saved to an account.
    @Published var needsAccountAfterPurchase: Bool {
        didSet {
            UserDefaults.standard.set(needsAccountAfterPurchase, forKey: "sl_needs_account_after_purchase")
        }
    }
    private init() {
        self.onboardingComplete = UserDefaults.standard.bool(forKey: "sl_onboarding_complete")
        self.needsAccountAfterPurchase = UserDefaults.standard.bool(forKey: "sl_needs_account_after_purchase")
        self.isGuest = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isGuest)
        setupNotificationObserver()
    }
    

    func beginGuestSession() {
        isGuest = true
        onboardingComplete = true
        shouldExitOnboarding = true
    }

    func endGuestSession() {
        isGuest = false
    }
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToPrayer"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let prayerType = userInfo["prayerType"] as? String {
                self?.selectedPrayerType = prayerType
                // Navigate to home tab for prayer times
                self?.selectedTab = AppEnums.TabItem.home.rawValue
                DebugLogger.log("Navigating to Home tab for: \(prayerType)")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
