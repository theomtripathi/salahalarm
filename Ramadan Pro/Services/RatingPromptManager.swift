import Foundation

/// Pure eligibility policy shared by the app-side scheduler and focused tests.
enum RatingPromptPolicy {
    static let minimumEligibleUseAge: TimeInterval = 24 * 60 * 60

    enum Decision: Equatable {
        case alreadyRequested
        case notForeground
        case modalPresented
        case notEntitled
        case establishFirstEligibleUse
        case waitForOneDay
        case request
    }

    static func decision(
        now: Date,
        firstEligibleUse: Date?,
        didRequest: Bool,
        hasActiveEntitlement: Bool,
        isForeground: Bool,
        isModalPresented: Bool
    ) -> Decision {
        guard !didRequest else { return .alreadyRequested }
        guard isForeground else { return .notForeground }
        guard !isModalPresented else { return .modalPresented }
        guard hasActiveEntitlement else { return .notEntitled }
        guard let firstEligibleUse else { return .establishFirstEligibleUse }
        guard now.timeIntervalSince(firstEligibleUse) >= minimumEligibleUseAge else {
            return .waitForOneDay
        }
        return .request
    }
}

#if canImport(UIKit) && canImport(StoreKit) && canImport(RevenueCat)
import StoreKit
import UIKit
import RevenueCat

/// Requests Apple's native App Store rating prompt once, after a qualifying
/// subscriber/trial user's first eligible use and a later foreground return.
@MainActor
final class RatingPromptManager {
    static let shared = RatingPromptManager()

    private enum Key {
        static let didRequest = "rating_prompt_did_request"
        static let firstEligibleUsePrefix = "rating_prompt_first_eligible_use"
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private let identity: () -> String?
    private let requestReview: @MainActor (UIWindowScene) -> Void

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        identity: @escaping () -> String? = { Purchases.shared.appUserID },
        requestReview: @escaping @MainActor (UIWindowScene) -> Void = {
            SKStoreReviewController.requestReview(in: $0)
        }
    ) {
        self.defaults = defaults
        self.now = now
        self.identity = identity
        self.requestReview = requestReview
    }

    /// Kept for existing app-activation callers. Prompt eligibility is now
    /// evaluated only by MainTabView after its delayed foreground check.
    func recordAppActivation() {}

    func considerForegroundReturn(
        hasActiveEntitlement: Bool,
        scene: UIWindowScene,
        isModalPresented: Bool
    ) {
        let key = firstEligibleUseKey
        let firstEligibleUse = defaults.object(forKey: key) as? Date
        let decision = RatingPromptPolicy.decision(
            now: now(),
            firstEligibleUse: firstEligibleUse,
            didRequest: defaults.bool(forKey: Key.didRequest),
            hasActiveEntitlement: hasActiveEntitlement,
            isForeground: scene.activationState == .foregroundActive,
            isModalPresented: isModalPresented
        )

        switch decision {
        case .establishFirstEligibleUse:
            defaults.set(now(), forKey: key)
        case .request:
            // StoreKit has no result callback proving display or rating.
            defaults.set(true, forKey: Key.didRequest)
            FunnelAnalytics.shared.track(.ratingPromptRequested, [:])
            requestReview(scene)
        case .alreadyRequested, .notForeground, .modalPresented,
             .notEntitled, .waitForOneDay:
            break
        }
    }

    func recordFirstEligibleUseIfNeeded(hasActiveEntitlement: Bool) {
        guard hasActiveEntitlement,
              !defaults.bool(forKey: Key.didRequest),
              defaults.object(forKey: firstEligibleUseKey) == nil else { return }
        defaults.set(now(), forKey: firstEligibleUseKey)
    }

    private var firstEligibleUseKey: String {
        guard let identity = identity(), !identity.isEmpty else {
            return Key.firstEligibleUsePrefix
        }
        // Identity is used only as a local UserDefaults namespace; it is not
        // sent to analytics or StoreKit.
        let suffix = Data(identity.utf8).base64EncodedString()
        return "\(Key.firstEligibleUsePrefix).\(suffix)"
    }
}
#endif
