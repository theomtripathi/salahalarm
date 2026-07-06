//
//  Subscription.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation

/// Subscription plan type
enum SubscriptionPlanType: String, Codable {
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

/// Subscription plan details
struct SubscriptionPlanDetails: Identifiable, Codable {
    let id: UUID
    let type: SubscriptionPlanType
    let price: Double // Price in dollars
    let priceString: String // Formatted price string (e.g., "$9.99")
    let features: [String]
    let isBestValue: Bool
    let productId: String? // App Store product ID
    let billingPeriodLabel: String
    let pricePerPeriodText: String
    let trialLabel: String?
    let renewalDescription: String?
    
    init(id: UUID = UUID(),
         type: SubscriptionPlanType,
         price: Double,
         priceString: String? = nil,
         features: [String] = [],
         isBestValue: Bool = false,
         productId: String? = nil,
         billingPeriodLabel: String? = nil,
         pricePerPeriodText: String? = nil,
         trialLabel: String? = nil,
         renewalDescription: String? = nil) {
        self.id = id
        self.type = type
        self.price = price
        self.priceString = priceString ?? String(format: "$%.2f", price)
        self.features = features
        self.isBestValue = isBestValue
        self.productId = productId
        let resolvedBillingPeriodLabel = billingPeriodLabel ?? type.rawValue
        self.billingPeriodLabel = resolvedBillingPeriodLabel
        self.pricePerPeriodText = pricePerPeriodText ?? "\(self.priceString) / \(resolvedBillingPeriodLabel)"
        self.trialLabel = trialLabel
        self.renewalDescription = renewalDescription
    }
}

/// Subscription status and information
struct SubscriptionStatus: Codable {
    let isActive: Bool
    let planType: SubscriptionPlanType?
    let startDate: Date?
    let expiryDate: Date?
    let autoRenew: Bool
    let cancelledDate: Date?
    let trialEndDate: Date?
    let isInTrial: Bool
    
    init(isActive: Bool = false,
         planType: SubscriptionPlanType? = nil,
         startDate: Date? = nil,
         expiryDate: Date? = nil,
         autoRenew: Bool = true,
         cancelledDate: Date? = nil,
         trialEndDate: Date? = nil,
         isInTrial: Bool = false) {
        self.isActive = isActive
        self.planType = planType
        self.startDate = startDate
        self.expiryDate = expiryDate
        self.autoRenew = autoRenew
        self.cancelledDate = cancelledDate
        self.trialEndDate = trialEndDate
        self.isInTrial = isInTrial
    }
    
    /// Check if subscription is expired
    var isExpired: Bool {
        guard let expiryDate = expiryDate else { return !isActive }
        return Date() > expiryDate
    }
    
    /// Days remaining until expiry
    var daysRemaining: Int? {
        guard let expiryDate = expiryDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiryDate)
        return components.day
    }
    
    /// Save to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "subscription_status")
        }
    }
    
    /// Load from UserDefaults
    static func load() -> SubscriptionStatus {
        guard let data = UserDefaults.standard.data(forKey: "subscription_status"),
              let status = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) else {
            return SubscriptionStatus() // Return inactive status if not found
        }
        return status
    }
}

/// Purchase receipt from App Store
struct PurchaseReceipt: Identifiable, Codable {
    let id: UUID
    let transactionId: String
    let productId: String
    let purchaseDate: Date
    let expiryDate: Date?
    let originalTransactionId: String?
    let receiptData: Data? // Base64 encoded receipt data
    
    init(id: UUID = UUID(),
         transactionId: String,
         productId: String,
         purchaseDate: Date = Date(),
         expiryDate: Date? = nil,
         originalTransactionId: String? = nil,
         receiptData: Data? = nil) {
        self.id = id
        self.transactionId = transactionId
        self.productId = productId
        self.purchaseDate = purchaseDate
        self.expiryDate = expiryDate
        self.originalTransactionId = originalTransactionId
        self.receiptData = receiptData
    }
}

/// Subscription API response
struct SubscriptionAPIResponse: Codable {
    let success: Bool
    let subscription: SubscriptionStatus?
    let message: String?
    let error: String?
}

/// Purchase API response
struct PurchaseAPIResponse: Codable {
    let success: Bool
    let transactionId: String?
    let subscription: SubscriptionStatus?
    let receipt: PurchaseReceipt?
    let message: String?
    let error: String?
}
