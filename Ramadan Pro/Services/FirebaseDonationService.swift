//
//  FirebaseDonationService.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for managing donations in Firestore
@MainActor
class FirebaseDonationService {
    static let shared = FirebaseDonationService()
    
    private let db = Firestore.firestore()
    private let donationsCollection = "donations"
    private let leaderboardCollection = "leaderboard"
    
    private init() {
        print("🔧 FirebaseDonationService: Initialized")
    }
    
    // MARK: - Save Donation
    
    /// Save a donation to Firestore
    func saveDonation(_ donation: Donation, userId: String) async throws {
        print("💾 FirebaseDonationService: Saving donation \(donation.id) for user \(userId)")
        
        let donationData: [String: Any] = [
            "id": donation.id.uuidString,
            "userId": userId,
            "amount": donation.amount,
            "mealsProvided": donation.mealsProvided,
            "timestamp": Timestamp(date: donation.timestamp),
            "transactionId": donation.transactionId ?? NSNull(),
            "receiptId": donation.receiptId ?? NSNull(),
            "status": donation.status.rawValue
        ]
        
        try await db.collection(donationsCollection).document(donation.id.uuidString).setData(donationData)
        print("✅ FirebaseDonationService: Donation saved successfully")
        
        // Update user's impact in users collection
        try await updateUserImpact(userId: userId, donation: donation)
        
        // Update leaderboard
        try await updateLeaderboard(userId: userId, donation: donation)
    }
    
    // MARK: - Fetch Donations
    
    /// Fetch all donations for a user
    func fetchDonations(userId: String) async throws -> [Donation] {
        print("📡 FirebaseDonationService: Fetching donations for user \(userId)")
        
        let snapshot = try await db.collection(donationsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        var donations: [Donation] = []
        
        for document in snapshot.documents {
            if let donation = decodeDonation(from: document.data(), documentId: document.documentID) {
                donations.append(donation)
            }
        }
        
        print("✅ FirebaseDonationService: Fetched \(donations.count) donations")
        return donations
    }
    
    // MARK: - Fetch Impact
    
    /// Fetch user's impact from Firestore
    func fetchImpact(userId: String) async throws -> Impact {
        print("📡 FirebaseDonationService: Fetching impact for user \(userId)")
        
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = userDoc.data(),
              let impactData = data["impact"] as? [String: Any] else {
            print("⚠️ FirebaseDonationService: No impact data found, returning empty impact")
            return Impact()
        }
        
        let totalDonations = impactData["totalDonations"] as? Int ?? 0
        let totalMeals = impactData["totalMeals"] as? Int ?? 0
        let donationCount = impactData["donationCount"] as? Int ?? 0
        let lastDonationDate = (impactData["lastDonationDate"] as? Timestamp)?.dateValue()
        
        let impact = Impact(
            totalDonations: totalDonations,
            totalMeals: totalMeals,
            donationCount: donationCount,
            lastDonationDate: lastDonationDate
        )
        
        print("✅ FirebaseDonationService: Fetched impact - $\(totalDonations), \(totalMeals) meals, \(donationCount) donations")
        return impact
    }
    
    // MARK: - Fetch Leaderboard
    
    /// Fetch top contributors leaderboard
    func fetchLeaderboard(limit: Int = 10) async throws -> [LeaderboardEntry] {
        print("📡 FirebaseDonationService: Fetching leaderboard (top \(limit))")
        
        let snapshot = try await db.collection(leaderboardCollection)
            .order(by: "totalAmount", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        var entries: [LeaderboardEntry] = []
        var rank = 1
        
        for document in snapshot.documents {
            if let entry = decodeLeaderboardEntry(from: document.data(), rank: rank) {
                entries.append(entry)
                rank += 1
            }
        }
        
        print("✅ FirebaseDonationService: Fetched \(entries.count) leaderboard entries")
        return entries
    }
    
    // MARK: - Update User Impact
    
    /// Update user's impact in Firestore
    private func updateUserImpact(userId: String, donation: Donation) async throws {
        print("💾 FirebaseDonationService: Updating impact for user \(userId)")
        
        let userRef = db.collection("users").document(userId)
        let userDoc = try await userRef.getDocument()
        
        var impactData: [String: Any] = [:]
        
        if let data = userDoc.data(),
           let existingImpact = data["impact"] as? [String: Any] {
            let totalDonations = (existingImpact["totalDonations"] as? Int ?? 0) + donation.amount
            let totalMeals = (existingImpact["totalMeals"] as? Int ?? 0) + donation.mealsProvided
            let donationCount = (existingImpact["donationCount"] as? Int ?? 0) + 1
            
            impactData = [
                "totalDonations": totalDonations,
                "totalMeals": totalMeals,
                "donationCount": donationCount,
                "lastDonationDate": Timestamp(date: donation.timestamp)
            ]
        } else {
            // First donation
            impactData = [
                "totalDonations": donation.amount,
                "totalMeals": donation.mealsProvided,
                "donationCount": 1,
                "lastDonationDate": Timestamp(date: donation.timestamp)
            ]
        }
        
        try await userRef.setData(["impact": impactData], merge: true)
        print("✅ FirebaseDonationService: User impact updated")
    }
    
    // MARK: - Update Leaderboard
    
    /// Update leaderboard entry for a user
    private func updateLeaderboard(userId: String, donation: Donation) async throws {
        print("💾 FirebaseDonationService: Updating leaderboard for user \(userId)")
        
        // Get user's name (or use "Anonymous")
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let userName = userDoc.data()?["name"] as? String ?? "Anonymous"
        
        let leaderboardRef = db.collection(leaderboardCollection).document(userId)
        let leaderboardDoc = try await leaderboardRef.getDocument()
        
        if leaderboardDoc.exists {
            // Update existing entry
            let data = leaderboardDoc.data() ?? [:]
            let currentTotal = (data["totalAmount"] as? Int ?? 0) + donation.amount
            let currentMeals = (data["totalMeals"] as? Int ?? 0) + donation.mealsProvided
            
            try await leaderboardRef.updateData([
                "totalAmount": currentTotal,
                "totalMeals": currentMeals,
                "lastDonationDate": Timestamp(date: donation.timestamp)
            ])
        } else {
            // Create new entry
            try await leaderboardRef.setData([
                "userId": userId,
                "name": userName,
                "totalAmount": donation.amount,
                "totalMeals": donation.mealsProvided,
                "lastDonationDate": Timestamp(date: donation.timestamp),
                "isAnonymous": false
            ])
        }
        
        print("✅ FirebaseDonationService: Leaderboard updated")
    }
    
    // MARK: - Delete Donations
    
    /// Delete all donations for a user (useful for account deletion)
    func deleteAllDonations(userId: String) async throws {
        print("🗑️ FirebaseDonationService: Deleting all donations for user \(userId)")
        
        let snapshot = try await db.collection(donationsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for document in snapshot.documents {
            try await document.reference.delete()
        }
        
        // Also remove from leaderboard
        try? await db.collection(leaderboardCollection).document(userId).delete()
        
        print("✅ FirebaseDonationService: Deleted \(snapshot.documents.count) donations")
    }
    
    // MARK: - Helper Methods
    
    /// Decode Donation from Firestore data
    private func decodeDonation(from data: [String: Any], documentId: String) -> Donation? {
        guard let amount = data["amount"] as? Int,
              let mealsProvided = data["mealsProvided"] as? Int,
              let statusString = data["status"] as? String,
              let status = DonationStatus(rawValue: statusString) else {
            print("❌ FirebaseDonationService: Invalid donation data")
            return nil
        }
        
        let id = UUID(uuidString: documentId) ?? UUID()
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let transactionId = data["transactionId"] as? String
        let receiptId = data["receiptId"] as? String
        
        return Donation(
            id: id,
            amount: amount,
            mealsProvided: mealsProvided,
            timestamp: timestamp,
            transactionId: transactionId,
            receiptId: receiptId,
            status: status
        )
    }
    
    /// Decode LeaderboardEntry from Firestore data
    private func decodeLeaderboardEntry(from data: [String: Any], rank: Int) -> LeaderboardEntry? {
        guard let name = data["name"] as? String,
              let totalAmount = data["totalAmount"] as? Int,
              let totalMeals = data["totalMeals"] as? Int else {
            print("❌ FirebaseDonationService: Invalid leaderboard entry data")
            return nil
        }
        
        let isAnonymous = data["isAnonymous"] as? Bool ?? false
        
        return LeaderboardEntry(
            rank: rank,
            name: name,
            amount: totalAmount,
            mealsProvided: totalMeals,
            isAnonymous: isAnonymous
        )
    }
}
