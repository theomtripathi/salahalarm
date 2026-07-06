//
//  ProfileViewModel.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for managing user profile and preferences
@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var user: User?
    @Published var preferences: UserPreferences = UserPreferences()
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // TODO: Add API service when backend is ready
    // private let apiService: UserAPIService
    
    init() {
        loadUser()
        loadPreferences()
        loadSubscriptionStatus()
    }
    
    // MARK: - Public Methods
    
    /// Load user from local storage
    func loadUser() {
        self.user = User.load()
    }
    
    /// Load user from API
    func loadUserFromAPI() async {
        isLoading = true
        errorMessage = nil
        
        // TODO: Replace with API call
        // do {
        //     let response = try await apiService.fetchUser()
        //     if response.success, let user = response.user {
        //         self.user = user
        //         user.save()
        //         isLoading = false
        //     } else {
        //         errorMessage = response.error ?? "Failed to load user"
        //         isLoading = false
        //     }
        // } catch {
        //     errorMessage = error.localizedDescription
        //     isLoading = false
        // }
        
        // Temporary: Use local user or create default
        if user == nil {
            // Create a default user for now
            let defaultUser = User(userId: UUID().uuidString, name: "User Name")
            self.user = defaultUser
            defaultUser.save()
        }
        isLoading = false
    }
    
    /// Update user name
    func updateUserName(_ name: String) async {
        guard var currentUser = user else { return }
        
        // TODO: Replace with API call
        // do {
        //     let response = try await apiService.updateUser(name: name)
        //     if response.success, let updatedUser = response.user {
        //         self.user = updatedUser
        //         updatedUser.save()
        //     }
        // } catch {
        //     errorMessage = error.localizedDescription
        // }
        
        // Temporary: Update local user
        let updatedUser = User(
            userId: currentUser.userId,
            email: currentUser.email,
            name: name,
            createdAt: currentUser.createdAt,
            lastLoginAt: Date(),
            subscriptionStatus: currentUser.subscriptionStatus
        )
        self.user = updatedUser
        updatedUser.save()
    }
    
    /// Load preferences from local storage
    func loadPreferences() {
        self.preferences = UserPreferences.load()
    }
    
    /// Update preferences
    func updatePreferences(_ newPreferences: UserPreferences) async {
        self.preferences = newPreferences
        newPreferences.save()
        
        // TODO: Sync with backend
        // await apiService.updatePreferences(newPreferences)
    }
    
    /// Load subscription status
    func loadSubscriptionStatus() {
        self.subscriptionStatus = SubscriptionStatus.load()
    }
    
    /// Logout user
    func logout() {
        // Clear user data
        User.clear()
        user = nil
        
        // Clear preferences (optional - might want to keep them)
        // UserPreferences().save()
        
        // Clear subscription status (optional)
        // SubscriptionStatus().save()
        
        // TODO: Call logout API
        // Task {
        //     await apiService.logout()
        // }
    }
    
    /// Check if user has active subscription
    var hasActiveSubscription: Bool {
        return subscriptionStatus.isActive && !subscriptionStatus.isExpired
    }
    
    /// Get user display name
    var displayName: String {
        return user?.name ?? "User Name"
    }
}
