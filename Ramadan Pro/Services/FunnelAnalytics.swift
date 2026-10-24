import Foundation
import FirebaseAnalytics
import PostHog
import UIKit

enum FunnelEvent: String {
    case appInstalled = "app_installed"
    case onboardingStarted = "onboarding_started"
    case onboardingScreenViewed = "onboarding_screen_viewed"
    case onboardingScreenCompleted = "onboarding_screen_completed"
    case onboardingAbandoned = "onboarding_abandoned"
    case onboardingCompleted = "onboarding_completed"
    case onboardingFinished = "onboarding_finished"
    case onboardingQuestionnaireCompleted = "onboarding_questionnaire_completed"
    case onboardingResumed = "onboarding_resumed"
    case onboardingPaused = "onboarding_paused"
    case onboardingAction = "onboarding_action"
    case onboardingSelectionChanged = "onboarding_selection_changed"
    case onboardingSurfaceViewed = "onboarding_surface_viewed"
    case onboardingLanguageSelected = "onboarding_language_selected"
    case onboardingLanguageConfirmed = "onboarding_language_confirmed"
    case signupStarted = "signup_started"
    case signupCompleted = "signup_completed"
    case signupSkipped = "signup_skipped"
    case paywallViewed = "paywall_viewed"
    case pricingPlanSelected = "pricing_plan_selected"
    case purchaseInitiated = "purchase_initiated"
    case purchaseCheckoutStarted = "purchase_checkout_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case purchaseCancelled = "purchase_cancelled"
    case purchasePending = "purchase_pending"
    case purchaseNotAllowed = "purchase_not_allowed"
    case paywallExited = "paywall_exited"
    case paywallCloseTapped = "paywall_close_tapped"
    case paywallExitReasonSubmitted = "paywall_exit_reason_submitted"
    case winBackModalShown = "win_back_modal_shown"
    case winBackOfferAccepted = "win_back_offer_accepted"
    case winBackOfferDeclined = "win_back_offer_declined"
    case winBackOfferUnavailable = "win_back_offer_unavailable"
    case trialOfferShown = "trial_offer_shown"
    case trialOfferAccepted = "trial_offer_accepted"
    case trialOfferDeclined = "trial_offer_declined"
    case trialOfferUnavailable = "trial_offer_unavailable"
    case trialStarted = "trial_started"
    case trialJourneyViewed = "trial_journey_viewed"
    case trialJourneyAction = "trial_journey_action"
    case paywallBackgrounded = "paywall_backgrounded"
    case paywallProductRejected = "paywall_product_rejected"
    case ratingPromptRequested = "rating_prompt_requested"
}

final class FunnelAnalytics {
    static let shared = FunnelAnalytics()
    static let onboardingVersion = "v4_localized_quick_start"
    private let installKey = "posthog_install_tracked"
    private let onboardingKey = "posthog_onboarding_started_v4_localized_quick_start"
    private var journey = OnboardingJourney()
    private var onboardingStarted = false
    private var trackingActive = false
    private var lastViewedScreen: OnboardingScreenID?
    private var hasFinished = false
    private var appLanguage: String { AppLanguage.current.rawValue }
    private var layoutDirection: String { AppLanguage.current.isRightToLeft ? "rtl" : "ltr" }
    private var lastOnboardingScreen: (name: String, index: Int)?
    private var didCompleteOnboarding = false
    private var isConfigured = false
    private var featureFlagsObserver: NSObjectProtocol?
    private var replayLayoutTask: Task<Void, Never>?

    private init() {}

    func configure() {
        guard !isConfigured else { return }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "PostHogAPIKey") as? String,
              !key.isEmpty else { return }
        let host = (Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String) ?? "https://us.i.posthog.com"
        let config = PostHogConfig(projectToken: key, host: host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        // SwiftUI onboarding controls emit explicit, allowlisted events instead.
        config.captureElementInteractions = false
        // SwiftUI hosting controllers cannot produce wireframe snapshots.
        // Without screenshot mode, touches/network events arrive but replay has no frames.
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true
        config.sessionReplayConfig.sampleRate = 1.0
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = true
        config.sessionReplayConfig.maskAllSandboxedViews = true
        // Send short sessions promptly. The SDK keeps its persistent offline queue
        // and retries delivery when connectivity returns.
        config.flushAt = 5
        config.flushIntervalSeconds = 10
        // Let the SDK's initial recording-settings request wait for connectivity
        // during an offline launch, instead of failing before a network path exists.
        let networkConfiguration = URLSessionConfiguration.default
        networkConfiguration.waitsForConnectivity = true
        config.urlSessionConfiguration = networkConfiguration

        featureFlagsObserver = NotificationCenter.default.addObserver(
            forName: PostHogSDK.didReceiveFeatureFlags,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Allow the SDK's config callbacks to finish installing the recorder
            // before requesting the initial SwiftUI layout/snapshot.
            DispatchQueue.main.async {
                self?.resumeSessionReplay(reason: "remote_config_updated")
            }
        }
        PostHogSDK.shared.setup(config)
        isConfigured = true
        PostHogSDK.shared.register([
            "analytics_schema_version": 3,
            "session_replay_mode": "screenshot",
            "session_replay_privacy": "masked_by_default_public_paywalls_readable",
            "session_replay_sample_rate": 1.0
        ])
        #if DEBUG
        if let verificationID = ProcessInfo.processInfo.environment["POSTHOG_REPLAY_VERIFICATION_ID"] {
            PostHogSDK.shared.register([
                "internal_test_session": true,
                "replay_verification_id": verificationID
            ])
        }
        #endif
    }

    @MainActor
    func applicationDidBecomeActive() {
        resumeOnboardingJourney()
        guard isConfigured else { return }
        resumeSessionReplay(reason: "app_active")
    }

    @MainActor
    private func resumeSessionReplay(reason: String) {
        // Resume the same session; this respects PostHog's remote recording settings.
        PostHogSDK.shared.startSessionRecording()
        if PostHogSDK.shared.isSessionReplayActive() {
            // Recording settings may arrive after the first screen has finished
            // laying out. The recorder listens to layout events, so ensure a static
            // opening screen gets a frame without waiting for the first user tap.
            requestReplayLayout()
        }
        recordSessionReplayStatus(reason: reason)
    }

    func applicationDidEnterBackground() {
        replayLayoutTask?.cancel()
        pauseOnboardingJourney()
        recordSessionReplayStatus(reason: "app_backgrounded")
        // Flush after the app's last custom events have been queued, as well as
        // the SDK's own background flush. Both events and snapshots are flushed.
        PostHogSDK.shared.flush()
    }

    /// Bounded redraws cover a recorder becoming ready before the SwiftUI window
    /// is attached. No SDK reset, new session, private capture API, or polling loop.
    @MainActor
    private func requestReplayLayout() {
        replayLayoutTask?.cancel()
        replayLayoutTask = Task { @MainActor in
            for delay in [0, 300_000_000, 700_000_000, 1_000_000_000] {
                if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay)) }
                guard !Task.isCancelled,
                      UIApplication.shared.applicationState == .active,
                      PostHogSDK.shared.isSessionReplayActive() else { return }
                for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                    where scene.activationState == .foregroundActive {
                    for window in scene.windows where window.isKeyWindow {
                        window.setNeedsLayout()
                        window.rootViewController?.view.setNeedsLayout()
                        window.layoutIfNeeded()
                        window.rootViewController?.view.layoutIfNeeded()
                    }
                }
            }
        }
    }

    private func recordSessionReplayStatus(reason: String) {
        guard isConfigured else { return }
        // Active means capture is running, not that the server has received frames.
        PostHogSDK.shared.capture("session_replay_status", properties: [
            "reason": reason,
            "replay_capture_active": PostHogSDK.shared.isSessionReplayActive()
        ])
    }
    func trackInstallIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: installKey) else { return }
        UserDefaults.standard.set(true, forKey: installKey)
        track(.appInstalled, ["platform": "iOS", "app_version": Bundle.main.appVersion, "install_source": "unknown"])
    }

    func onboardingStartedIfNeeded() {
        guard !onboardingStarted else { return }
        onboardingStarted = true
        guard !UserDefaults.standard.bool(forKey: onboardingKey) else { return }
        UserDefaults.standard.set(true, forKey: onboardingKey)
        track(.onboardingStarted, ["onboarding_version": Self.onboardingVersion])
    }

    func onboardingScreenViewed(screen: OnboardingScreenID) {
        guard trackingActive, lastViewedScreen != screen, let index = screen.funnelIndex else { return }
        let visit = journey.start(screen: screen.analyticsName, index: index)
        lastViewedScreen = screen
        track(.onboardingScreenViewed, ["screen_name": screen.analyticsName, "screen_index": index, "visit_id": visit.id, "journey_id": journey.journeyID])
        PostHogSDK.shared.screen(screen.analyticsName)
        Task { @MainActor in
            self.resumeSessionReplay(reason: "onboarding_screen_visible")
        }
    }

    func onboardingScreenCompleted(screen: OnboardingScreenID, timeSpent: TimeInterval) {
        guard trackingActive, let index = screen.funnelIndex else { return }
        track(.onboardingScreenCompleted, ["screen_name": screen.analyticsName, "screen_index": index, "time_spent_seconds": max(0, Int(timeSpent)), "journey_id": journey.journeyID])
    }

    func onboardingCompleted() {
        onboardingQuestionnaireCompleted()
    }
    func onboardingQuestionnaireCompleted() {
        guard trackingActive, !didCompleteOnboarding else { return }
        didCompleteOnboarding = true
        track(.onboardingQuestionnaireCompleted, ["journey_id": journey.journeyID])
    }
    func onboardingFinished() {
        // This means onboarding setup was actually completed, not merely that
        // the user reached the paywall (which remains back-navigable).
        guard trackingActive, !hasFinished else { return }
        hasFinished = true
        let totals = journey.finish()
        track(.onboardingFinished, ["total_active_time_seconds": totals.elapsedActiveSeconds, "screens_seen_count": totals.screensSeenCount, "journey_id": journey.journeyID])
        trackingActive = false
    }
    func startOnboardingAnalytics(screen: OnboardingScreenID) {
        guard !trackingActive else { return }
        trackingActive = true
        onboardingStartedIfNeeded()
        if lastViewedScreen != nil { track(.onboardingResumed, ["journey_id": journey.journeyID]) }
        onboardingScreenViewed(screen: screen)
    }
    func transitionOnboarding(to screen: OnboardingScreenID, completed: Bool) {
        guard trackingActive, let index = screen.funnelIndex else { return }
        if let transition = journey.transition(to: screen.analyticsName, index: index, completed: completed) {
            if completed {
                track(.onboardingScreenCompleted, ["screen_name": transition.previous.screen, "screen_index": transition.previous.index, "visit_id": transition.previous.id, "time_spent_seconds": transition.elapsedActiveSeconds, "journey_id": journey.journeyID])
            }
        }
        lastViewedScreen = screen
        let visitID = journey.currentVisit?.id ?? ""
        track(.onboardingScreenViewed, ["screen_name": screen.analyticsName, "screen_index": index, "visit_id": visitID, "journey_id": journey.journeyID])
        PostHogSDK.shared.screen(screen.analyticsName)
    }
    func pauseOnboardingJourney() {
        guard trackingActive else { return }
        journey.pause()
        trackingActive = false
        track(.onboardingPaused, ["journey_id": journey.journeyID])
    }
    func resumeOnboardingJourney() {
        guard !trackingActive, !hasFinished else { return }
        journey.resume()
        trackingActive = true
        track(.onboardingResumed, ["journey_id": journey.journeyID, "state": "active"])
    }
    func onboardingSurfaceViewed(name: String) {
        let allowed = ["language_selection", "email_signup", "email_signin", "purchase_error", "exit_feedback"]
        guard allowed.contains(name) else { return }
        track(.onboardingSurfaceViewed, ["surface_name": name, "journey_id": journey.journeyID])
    }
    func onboardingAction(_ actionID: String) {
        let allowed = ["continue_tapped", "skip_tapped", "back_tapped", "sign_in_tapped", "create_account_tapped", "permission_requested", "permission_result"]
        guard trackingActive, allowed.contains(actionID) else { return }
        var properties: [String: Any] = ["action_id": actionID, "journey_id": journey.journeyID]
        if let visit = journey.currentVisit {
            properties["visit_id"] = visit.id
            properties["screen_name"] = visit.screen
            properties["screen_index"] = visit.index
        }
        track(.onboardingAction, properties)
    }
    func onboardingSelectionChanged(questionID: String, selectionCount: Int) {
        let allowed = ["goals", "support_pace"]
        guard trackingActive, allowed.contains(questionID) else { return }
        track(.onboardingSelectionChanged, ["question_id": questionID, "selection_count": max(0, selectionCount), "journey_id": journey.journeyID])
    }
    func onboardingAction(action: String, screen: OnboardingScreenID, questionID: String? = nil, selectionCount: Int? = nil, permissionReason: String? = nil) {
        let actions = ["continue_tapped", "skip_tapped", "back_tapped", "sign_in_tapped", "create_account_tapped", "permission_requested", "permission_result"]
        guard trackingActive, actions.contains(action) else { return }
        var properties: [String: Any] = ["action_id": action, "screen_name": screen.analyticsName, "journey_id": journey.journeyID]
        if let visit = journey.currentVisit {
            properties["visit_id"] = visit.id
            properties["screen_index"] = visit.index
        }
        if let questionID, ["goals", "support_pace"].contains(questionID) { properties["question_id"] = questionID }
        if let selectionCount, questionID != nil { properties["selection_count"] = max(0, selectionCount) }
        if action == "permission_result", let permissionReason, ["granted", "denied", "restricted", "not_determined", "unavailable"].contains(permissionReason) { properties["permission_reason"] = permissionReason }
        track(.onboardingAction, properties)
    }
    func onboardingLanguageSelected(languageCode: String, source: String) {
        let safeSource = ["language_picker", "onboarding"].contains(source) ? source : "onboarding"
        track(.onboardingLanguageSelected, ["language_code": safeLanguageCode(languageCode), "source": safeSource, "journey_id": journey.journeyID])
    }
    func onboardingLanguageConfirmed(languageCode: String, source: String) {
        let safeSource = ["language_picker", "onboarding"].contains(source) ? source : "onboarding"
        track(.onboardingLanguageConfirmed, ["language_code": safeLanguageCode(languageCode), "source": safeSource, "journey_id": journey.journeyID])
    }
    private func safeLanguageCode(_ value: String) -> String {
        let code = value.lowercased().components(separatedBy: CharacterSet(charactersIn: "-_")).first ?? ""
        return code.range(of: "^[a-z]{2,3}$", options: .regularExpression) != nil ? code : "other"
    }
    func signupCompleted(method: String) { track(.signupCompleted, ["signup_method": method]) }
    func track(_ event: FunnelEvent, _ properties: [String: Any] = [:]) {
        var enrichedProperties = properties
        enrichedProperties["onboarding_version"] = enrichedProperties["onboarding_version"] ?? Self.onboardingVersion
        enrichedProperties["app_language"] = appLanguage
        enrichedProperties["layout_direction"] = layoutDirection
        enrichedProperties["replay_capture_active"] = PostHogSDK.shared.isSessionReplayActive()
        // The event describes the purchase operation, not an inferred bank/card
        // verdict. In particular, an App Store error may leave charge status unknown.
        switch event {
        case .purchaseCompleted:
            enrichedProperties["purchase_outcome"] = "completed"
            if properties["subscription_period_type"] as? String == "trial" {
                enrichedProperties["revenue_amount"] = 0
                enrichedProperties["renewal_price_amount"] = properties["price_amount"]
            }
        case .trialStarted:
            enrichedProperties["revenue_amount"] = 0
            enrichedProperties["renewal_price_amount"] = properties["price_amount"]
        case .purchaseCancelled:
            enrichedProperties["purchase_outcome"] = "cancelled"
        case .purchasePending:
            enrichedProperties["purchase_outcome"] = "pending"
        case .purchaseNotAllowed:
            enrichedProperties["purchase_outcome"] = "not_allowed"
            enrichedProperties["decline_status"] = "not_reported"
        case .purchaseFailed:
            enrichedProperties["purchase_outcome"] = "failed"
            enrichedProperties["decline_status"] = "not_reported"
            enrichedProperties["charge_status"] = enrichedProperties["charge_status"] ?? "unknown"
        case .paywallViewed:
            let name = properties["paywall_id"] as? String ?? "paywall"
            PostHogSDK.shared.screen(name)
            Task { @MainActor in
                self.resumeSessionReplay(reason: "paywall_visible")
            }
        default:
            break
        }
        PostHogSDK.shared.capture(event.rawValue, properties: enrichedProperties)
        if [.purchaseInitiated, .purchaseCheckoutStarted, .purchaseCompleted, .purchaseFailed, .purchaseCancelled, .purchasePending, .purchaseNotAllowed].contains(event) {
            PostHogSDK.shared.flush()
        }
        AppsFlyerService.shared.logEvent(event.rawValue, parameters: enrichedProperties)
    }
    func identify(userID: String) { PostHogSDK.shared.identify(userID) }
}

private extension Bundle {
    var appVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown" }
}

