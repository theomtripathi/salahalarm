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
    private init() {
        self.onboardingComplete = UserDefaults.standard.bool(forKey: "sl_onboarding_complete")
        setupNotificationObserver()
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
