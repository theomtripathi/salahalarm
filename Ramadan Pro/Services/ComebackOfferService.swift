import Foundation
import UIKit

/// The "come back" offer for people who signed in but never subscribed.
///
/// Two ways in:
/// 1. The email link https://salahalarm.com/go/comeback opens the app (Universal Link).
/// 2. Someone who already had an account signs in again, usually after reinstalling
///    from that same link. iOS can't carry a link through an App Store install, so the
///    returning sign-in stands in for it.
///
/// The offer itself is the App Store offer code COMEBACK33 (first year at the
/// discounted price, then the normal yearly price). Apple's redeem URL opens the
/// App Store sheet with the code already filled in, so the user only confirms.
@MainActor
final class ComebackOfferService: ObservableObject {
    static let shared = ComebackOfferService()

    static let offerCode = "COMEBACK33"
    static let appStoreAppID = "6758457826"
    static let redeemURL = URL(string: "https://apps.apple.com/redeem?ctx=offercodes&id=\(appStoreAppID)&code=\(offerCode)")!

    private let pendingKey = "comeback_offer_pending_source"
    private let lastShownKey = "comeback_offer_last_shown_at"
    /// A returning sign-in shows the offer at most once a week; a tapped link always shows it.
    private let returningCooldown: TimeInterval = 7 * 24 * 60 * 60

    /// Where the pending offer came from ("email_link" or "returning_sign_in"), or nil.
    @Published private(set) var pendingSource: String?

    private init() {
        pendingSource = UserDefaults.standard.string(forKey: pendingKey)
    }

    /// True for https://salahalarm.com/go/comeback (and www., with any query string).
    static func isComebackLink(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              host == "salahalarm.com" || host == "www.salahalarm.com" else { return false }
        return url.path.lowercased().hasPrefix("/go/comeback")
    }

    /// Handles an incoming URL. Returns true if it was the comeback link.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard Self.isComebackLink(url) else { return false }
        let ref = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "ref" })?.value ?? ""
        FunnelAnalytics.shared.track(.comebackLinkOpened, ["ref": ref])
        setPending("email_link")
        return true
    }

    /// Called after an existing account signs in again (not a brand-new account).
    func noteReturningSignIn() {
        if let last = UserDefaults.standard.object(forKey: lastShownKey) as? Date,
           Date().timeIntervalSince(last) < returningCooldown {
            return
        }
        setPending("returning_sign_in")
    }

    /// Whether the offer should be on screen right now.
    func shouldPresent(isAuthenticated: Bool, hasSubscription: Bool) -> Bool {
        pendingSource != nil && isAuthenticated && !hasSubscription
    }

    func markShown() {
        UserDefaults.standard.set(Date(), forKey: lastShownKey)
        FunnelAnalytics.shared.track(.comebackOfferShown, ["source": pendingSource ?? ""])
    }

    func redeem() {
        FunnelAnalytics.shared.track(.comebackOfferRedeemTapped, ["source": pendingSource ?? ""])
        UIApplication.shared.open(Self.redeemURL)
        // Keep the offer pending: if they come back without redeeming, it is still there.
        // A successful redemption flips the subscription to active, which hides it.
    }

    func dismiss() {
        FunnelAnalytics.shared.track(.comebackOfferDismissed, ["source": pendingSource ?? ""])
        clear()
    }

    func clear() {
        pendingSource = nil
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    private func setPending(_ source: String) {
        pendingSource = source
        UserDefaults.standard.set(source, forKey: pendingKey)
    }
}
