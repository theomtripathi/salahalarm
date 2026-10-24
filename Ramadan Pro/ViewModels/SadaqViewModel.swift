//
//  SadaqViewModel.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import RevenueCat

/// ViewModel for managing donations and impact
@MainActor
class SadaqViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var impact: Impact = Impact()
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var donations: [Donation] = []
    @Published var receipts: [DonationReceipt] = []
    
    @Published var isLoading: Bool = false
    @Published var isProcessingDonation: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let donationService = FirebaseDonationService.shared
    private let revenueCatService = RevenueCatService.shared
    
    init() {
        loadImpactLocal()
        loadDonationsLocal()
        // Load leaderboard asynchronously when needed
        // loadLeaderboard() is async, call it from view's .task modifier
    }
    
    // MARK: - Public Methods
    
    /// Process a donation with RevenueCat payment processing
    func processDonation(amount: Int) async -> Donation? {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please sign in to make a donation"
            return nil
        }
        
        isProcessingDonation = true
        errorMessage = nil
        
        do {
            // Find or create consumable product for this amount
            let productId = "com.ramadanpro.donation.\(amount)"
            // A donation is recorded only after StoreKit confirms the charge.
            // Never turn a missing product or failed/cancelled payment into a
            // completed Firebase donation.
            let donationPackages = await revenueCatService.fetchDonationProductPackages(offeringIdentifier: nil)
            guard let package = donationPackages.first(where: { $0.storeProduct.productIdentifier == productId }) else {
                errorMessage = "This donation amount is temporarily unavailable. Please try another amount."
                isProcessingDonation = false
                return nil
            }

            let purchase = try await revenueCatService.purchaseDonationPackage(package)
            guard !purchase.userCancelled else {
                errorMessage = "Payment was cancelled"
                isProcessingDonation = false
                return nil
            }
            let transactionId = purchase.transactionIdentifier
            print("✅ SadaqViewModel: Donation payment processed via RevenueCat - $\(amount)")
            
            // Create donation record
            let donation = Donation(
                amount: amount,
                mealsProvided: amount,
                timestamp: Date(),
                transactionId: transactionId,
                receiptId: UUID().uuidString,
                status: .completed
            )
            
            // Save to Firebase
            try await donationService.saveDonation(donation, userId: userId)
            
            // Update local state
            await updateImpact(donation: donation)
            await addDonation(donation)
            
            // Reload impact and donations from Firebase to ensure sync
            await loadImpact()
            await loadDonations()
            
            isProcessingDonation = false
            print("✅ SadaqViewModel: Donation processed successfully - $\(amount), \(amount) meals")
            return donation
        } catch {
            errorMessage = error.localizedDescription
            isProcessingDonation = false
            print("❌ SadaqViewModel: Error processing donation: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Load user impact from Firebase (with local fallback)
    func loadImpact() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            // Not authenticated, use local storage
            self.impact = Impact.load()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedImpact = try await donationService.fetchImpact(userId: userId)
            self.impact = fetchedImpact
            fetchedImpact.save() // Save to local storage as backup
            isLoading = false
            print("✅ SadaqViewModel: Impact loaded from Firebase - $\(fetchedImpact.totalDonations), \(fetchedImpact.totalMeals) meals")
        } catch {
            // Fallback to local storage if Firebase fails
            self.impact = Impact.load()
            isLoading = false
            print("⚠️ SadaqViewModel: Failed to load impact from Firebase, using local: \(error.localizedDescription)")
        }
    }
    
    /// Load user impact from local storage (synchronous version for init)
    private func loadImpactLocal() {
        self.impact = Impact.load()
    }
    
    /// Update impact with new donation
    private func updateImpact(donation: Donation) async {
        let newImpact = Impact(
            totalDonations: impact.totalDonations + donation.amount,
            totalMeals: impact.totalMeals + donation.mealsProvided,
            donationCount: impact.donationCount + 1,
            lastDonationDate: donation.timestamp
        )
        self.impact = newImpact
        newImpact.save()
        
        // TODO: Sync with backend
        // await apiService.updateImpact(newImpact)
    }
    
    /// Load donations from Firebase (with local fallback)
    func loadDonations() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            // Not authenticated, use local storage
            loadDonationsLocal()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedDonations = try await donationService.fetchDonations(userId: userId)
            self.donations = fetchedDonations
            saveDonations() // Save to local storage as backup
            isLoading = false
            print("✅ SadaqViewModel: Loaded \(fetchedDonations.count) donations from Firebase")
        } catch {
            // Fallback to local storage if Firebase fails
            loadDonationsLocal()
            isLoading = false
            print("⚠️ SadaqViewModel: Failed to load donations from Firebase, using local: \(error.localizedDescription)")
        }
    }
    
    
    /// Load donations from local storage
    private func loadDonationsLocal() {
        if let data = UserDefaults.standard.data(forKey: "user_donations"),
           let decoded = try? JSONDecoder().decode([Donation].self, from: data) {
            self.donations = decoded
        }
    }
    
    /// Add donation to list
    private func addDonation(_ donation: Donation) async {
        donations.insert(donation, at: 0) // Add to beginning
        saveDonations()
        
        // TODO: Sync with backend
        // await apiService.syncDonations(donations)
    }
    
    /// Save donations to local storage
    private func saveDonations() {
        if let encoded = try? JSONEncoder().encode(donations) {
            UserDefaults.standard.set(encoded, forKey: "user_donations")
        }
    }
    
    /// Load leaderboard from Firebase
    func loadLeaderboard() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let entries = try await donationService.fetchLeaderboard(limit: 10)
            self.leaderboard = entries
            isLoading = false
            print("✅ SadaqViewModel: Loaded \(entries.count) leaderboard entries from Firebase")
        } catch {
            // Fallback to sample data if Firebase fails
            loadSampleLeaderboard()
            isLoading = false
            print("⚠️ SadaqViewModel: Failed to load leaderboard from Firebase, using sample: \(error.localizedDescription)")
        }
    }
    
    /// Load donation receipts
    func loadReceipts() async {
        isLoading = true
        
        // TODO: Replace with API call
        // do {
        //     let receipts = try await apiService.fetchReceipts()
        //     self.receipts = receipts
        //     isLoading = false
        // } catch {
        //     errorMessage = error.localizedDescription
        //     isLoading = false
        // }
        
        // Temporary: Generate receipts from donations
        receipts = donations.compactMap { donation in
            guard let transactionId = donation.transactionId else { return nil }
            return DonationReceipt(
                donationId: donation.id,
                amount: donation.amount,
                mealsProvided: donation.mealsProvided,
                date: donation.timestamp,
                transactionId: transactionId,
                receiptNumber: "RCP-\(donation.id.uuidString.prefix(8).uppercased())"
            )
        }
        isLoading = false
    }
    
    // MARK: - Private Methods (Sample Data - Remove when backend is ready)
    
    private func loadSampleLeaderboard() {
        // Sample hardcoded leaderboard data
        leaderboard = [
            LeaderboardEntry(rank: 1, name: "Anonymous", amount: 9870, mealsProvided: 9870, isAnonymous: true),
            LeaderboardEntry(rank: 2, name: "A. Rahman", amount: 7420, mealsProvided: 7420, isAnonymous: false),
            LeaderboardEntry(rank: 3, name: "S. Ali", amount: 5180, mealsProvided: 5180, isAnonymous: false),
            LeaderboardEntry(rank: 4, name: "Anonymous", amount: 2950, mealsProvided: 2950, isAnonymous: true)
        ]
    }
}
