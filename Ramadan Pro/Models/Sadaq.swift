//
//  Sadaq.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation

/// Represents a donation made by the user
struct Donation: Identifiable, Codable {
    let id: UUID
    let amount: Int // Amount in dollars
    let mealsProvided: Int // 1 dollar = 1 meal
    let timestamp: Date
    let transactionId: String?
    let receiptId: String?
    let status: DonationStatus
    
    init(id: UUID = UUID(),
         amount: Int,
         mealsProvided: Int? = nil,
         timestamp: Date = Date(),
         transactionId: String? = nil,
         receiptId: String? = nil,
         status: DonationStatus = .completed) {
        self.id = id
        self.amount = amount
        self.mealsProvided = mealsProvided ?? amount // Default: $1 = 1 meal
        self.timestamp = timestamp
        self.transactionId = transactionId
        self.receiptId = receiptId
        self.status = status
    }
}

/// Status of a donation transaction
enum DonationStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case refunded = "refunded"
}

/// Total impact statistics for the user
struct Impact: Codable {
    let totalDonations: Int // Total amount donated in dollars
    let totalMeals: Int // Total meals provided
    let donationCount: Int // Number of donations made
    let lastDonationDate: Date?
    
    init(totalDonations: Int = 0,
         totalMeals: Int = 0,
         donationCount: Int = 0,
         lastDonationDate: Date? = nil) {
        self.totalDonations = totalDonations
        self.totalMeals = totalMeals
        self.donationCount = donationCount
        self.lastDonationDate = lastDonationDate
    }
    
    /// Save to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "user_impact")
        }
    }
    
    /// Load from UserDefaults
    static func load() -> Impact {
        guard let data = UserDefaults.standard.data(forKey: "user_impact"),
              let impact = try? JSONDecoder().decode(Impact.self, from: data) else {
            return Impact() // Return empty impact if not found
        }
        return impact
    }
}

/// Leaderboard entry for top contributors
struct LeaderboardEntry: Identifiable, Codable {
    let id: UUID
    let rank: Int
    let name: String // "Anonymous" if user chose to remain anonymous
    let amount: Int // Total amount donated
    let mealsProvided: Int
    let isAnonymous: Bool
    
    init(id: UUID = UUID(),
         rank: Int,
         name: String,
         amount: Int,
         mealsProvided: Int? = nil,
         isAnonymous: Bool = false) {
        self.id = id
        self.rank = rank
        self.name = name
        self.amount = amount
        self.mealsProvided = mealsProvided ?? amount
        self.isAnonymous = isAnonymous
    }
}

/// Donation receipt for tax/record keeping
struct DonationReceipt: Identifiable, Codable {
    let id: UUID
    let donationId: UUID
    let amount: Int
    let mealsProvided: Int
    let date: Date
    let transactionId: String
    let receiptNumber: String
    let taxDeductible: Bool
    
    init(id: UUID = UUID(),
         donationId: UUID,
         amount: Int,
         mealsProvided: Int,
         date: Date = Date(),
         transactionId: String,
         receiptNumber: String,
         taxDeductible: Bool = true) {
        self.id = id
        self.donationId = donationId
        self.amount = amount
        self.mealsProvided = mealsProvided
        self.date = date
        self.transactionId = transactionId
        self.receiptNumber = receiptNumber
        self.taxDeductible = taxDeductible
    }
}

/// API response for donations
struct DonationAPIResponse: Codable {
    let success: Bool
    let donation: Donation?
    let transactionId: String?
    let receiptId: String?
    let message: String?
    let error: String?
}

/// API response for leaderboard
struct LeaderboardAPIResponse: Codable {
    let success: Bool
    let entries: [LeaderboardEntry]?
    let userRank: Int?
    let message: String?
    let error: String?
}
