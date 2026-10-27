//
//  TikTokAdsService.swift
//  Ramadan Pro
//
//  TikTok App Events SDK integration for TikTok ads measurement.
//

import Foundation
import TikTokBusinessSDK

final class TikTokAdsService {
    static let shared = TikTokAdsService()

    private enum InfoKey {
        static let accessToken = "TikTokAccessToken"
        static let appId = "TikTokAppID"
        static let tiktokAppId = "TikTokAppTikTokID"
    }

    private var isConfigured = false

    private init() {}

    /// Call once from application(_:didFinishLaunchingWithOptions:).
    func configure() {
        guard !isConfigured else { return }

        guard
            let accessToken = plistValue(for: InfoKey.accessToken),
            let appId = plistValue(for: InfoKey.appId),
            let tiktokAppId = plistValue(for: InfoKey.tiktokAppId)
        else {
            print("TikTokAdsService: skipped configuration because TikTok credentials are missing")
            return
        }

        guard let config = TikTokConfig(accessToken: accessToken, appId: appId, tiktokAppId: tiktokAppId) else {
            print("TikTokAdsService: failed to create TikTok config")
            return
        }

        // AppsFlyer is already the app's SKAN attribution owner, so keep TikTok
        // from also updating SKAdNetwork conversion values.
        config.disableSKAdNetworkSupport()

        // RevenueCat owns purchase flow state; report successful purchases once
        // from RevenueCatService instead of allowing StoreKit auto-observation.
        config.disablePaymentTracking()

        #if DEBUG
        config.enableDebugMode()
        config.setLogLevel(TikTokLogLevelVerbose)
        #endif

        TikTokBusiness.initializeSdk(config) { [weak self] success, error in
            if success {
                self?.isConfigured = true
                print("TikTokAdsService: configured")
            } else {
                print("TikTokAdsService: configuration failed - \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }

    func trackPurchase(productId: String, value: Double, currency: String?) {
        guard isConfigured || TikTokBusiness.isInitialized() else { return }

        var properties: [String: Any] = [
            "content_id": productId,
            "content_type": "subscription",
            "value": value
        ]

        if let currency, !currency.isEmpty {
            properties["currency"] = currency
        }

        let event = TikTokBaseEvent(eventName: "Purchase", properties: properties, eventId: nil)
        TikTokBusiness.trackTTEvent(event)
    }

    /// A free trial starts access, not paid purchase revenue.
    func trackTrialStarted(productId: String) {
        guard isConfigured || TikTokBusiness.isInitialized() else { return }
        let event = TikTokBaseEvent(eventName: "StartTrial", properties: [
            "content_id": productId,
            "content_type": "subscription"
        ], eventId: nil)
        TikTokBusiness.trackTTEvent(event)
    }

    private func plistValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
