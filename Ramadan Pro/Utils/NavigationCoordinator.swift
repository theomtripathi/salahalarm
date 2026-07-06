//
//  NavigationCoordinator.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import SwiftUI
import Combine

/// Centralized navigation coordinator for the entire app
class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()
    
    // Navigation paths for different contexts
    @Published var homeNavigationPath: NavigationPath = NavigationPath()
    @Published var prayersNavigationPath: NavigationPath = NavigationPath()
    @Published var quranNavigationPath: NavigationPath = NavigationPath()
    @Published var qiblaNavigationPath: NavigationPath = NavigationPath()
    @Published var profileNavigationPath: NavigationPath = NavigationPath()
    
    // Modal presentation state
    @Published var presentedSheet: AppEnums.PresentedSheet?
    @Published var presentedFullScreenCover: AppEnums.PresentedFullScreenCover?
    
    private init() {}
    
    // MARK: - Navigation Methods
    
    /// Navigate to a specific route in the home tab
    func navigateToHomeRoute(_ route: AppEnums.NavigationRoute) {
        homeNavigationPath.append(route)
    }
    
    /// Navigate to a specific route in the quran tab
    func navigateToQuranRoute(_ route: AppEnums.NavigationRoute) {
        quranNavigationPath.append(route)
    }
    
    /// Navigate to a specific route in the qibla tab
    func navigateToQiblaRoute(_ route: AppEnums.NavigationRoute) {
        qiblaNavigationPath.append(route)
    }
    
    /// Navigate to a specific route in the prayers tab
    func navigateToPrayersRoute(_ route: AppEnums.NavigationRoute) {
        prayersNavigationPath.append(route)
    }
    
    /// Present a sheet
    func presentSheet(_ sheet: AppEnums.PresentedSheet) {
        presentedSheet = sheet
    }
    
    /// Dismiss current sheet
    func dismissSheet() {
        presentedSheet = nil
    }
    
    /// Present a full screen cover
    func presentFullScreenCover(_ cover: AppEnums.PresentedFullScreenCover) {
        presentedFullScreenCover = cover
    }
    
    /// Dismiss current full screen cover
    func dismissFullScreenCover() {
        presentedFullScreenCover = nil
    }
    
    /// Pop to root for a specific tab
    func popToRoot(for tab: AppEnums.TabItem) {
        switch tab {
        case .home:
            homeNavigationPath.removeLast(homeNavigationPath.count)
        case .prayers:
            prayersNavigationPath.removeLast(prayersNavigationPath.count)
        case .quran:
            quranNavigationPath.removeLast(quranNavigationPath.count)
        case .qibla:
            qiblaNavigationPath.removeLast(qiblaNavigationPath.count)
        case .profile:
            profileNavigationPath.removeLast(profileNavigationPath.count)
        }
    }
    
    /// Clear all navigation paths (e.g. on logout)
    func clearAllPaths() {
        homeNavigationPath = NavigationPath()
        prayersNavigationPath = NavigationPath()
        quranNavigationPath = NavigationPath()
        qiblaNavigationPath = NavigationPath()
        profileNavigationPath = NavigationPath()
    }

    /// Pop current view
    func pop(for tab: AppEnums.TabItem) {
        switch tab {
        case .home:
            if !homeNavigationPath.isEmpty {
                homeNavigationPath.removeLast()
            }
        case .prayers:
            if !prayersNavigationPath.isEmpty {
                prayersNavigationPath.removeLast()
            }
        case .quran:
            if !quranNavigationPath.isEmpty {
                quranNavigationPath.removeLast()
            }
        case .qibla:
            if !qiblaNavigationPath.isEmpty {
                qiblaNavigationPath.removeLast()
            }
        case .profile:
            if !profileNavigationPath.isEmpty {
                profileNavigationPath.removeLast()
            }
        }
    }
}
