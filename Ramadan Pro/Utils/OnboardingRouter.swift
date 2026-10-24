//
//  OnboardingRouter.swift
//  Ramadan Pro
//

import Foundation

enum OnboardingScreenID: String, CaseIterable, Codable {
    case screen0
    case screen1
    case screen2
    case screen3
    case screen4
    case screen5
    case screen6
    case screen7A
    case screen7B
    case screen8
    case screen9
    case screen10
    case screen10A
    case screen11
    case screen12
    case screen13
    case screen14
    case screen15
    case screen16
    case screen16A
    case screen16B
    case screen17
    case screen17A
    case screen17B
    case screen17C
    case screen17D
    case screen17E
    case screen17F
    case screen18
    case screen19
    case screen20
    case screen21
    case screen22
    case screen23
    case screen24
    case screen25A
    case screen25B
    case screen25
    case screen26
    case screen27
    case screen28
    case screen29
    case screen30
}

enum OnboardingRouter {
    /// Account creation (screen17) is not in the route: it comes after purchase, or from the paywall's close/sign-in path.
    static let quickStartRoute: [OnboardingScreenID] = [.screen1, .screen3, .screen6, .screen7A, .screen8, .screen10, .screen18]

    static func next(after screen: OnboardingScreenID) -> OnboardingScreenID? {
        if let index = quickStartRoute.firstIndex(of: screen), quickStartRoute.indices.contains(index + 1) {
            return quickStartRoute[index + 1]
        }
        if screen == .screen18 { return nil }
        let screenOrder = screen.funnelIndex ?? 0
        if let next = quickStartRoute.first(where: { ($0.funnelIndex ?? 0) > screenOrder }) { return next }
        return quickStartRoute.last
    }

    static func previous(before screen: OnboardingScreenID) -> OnboardingScreenID? {
        if let index = quickStartRoute.firstIndex(of: screen), index > 0 { return quickStartRoute[index - 1] }
        let screenOrder = screen.funnelIndex ?? 0
        return quickStartRoute.last(where: { ($0.funnelIndex ?? 0) < screenOrder })
    }

    static func progress(for screen: OnboardingScreenID) -> Double? {
        if let index = quickStartRoute.firstIndex(of: screen) {
            return Double(index + 1) / Double(quickStartRoute.count)
        }
        if screen == .screen0 { return 0 }
        let order = OnboardingScreenID.allCases.firstIndex(of: screen) ?? 0
        let previous = quickStartRoute.last { (OnboardingScreenID.allCases.firstIndex(of: $0) ?? 0) < order }
        let next = quickStartRoute.first { (OnboardingScreenID.allCases.firstIndex(of: $0) ?? 0) > order }
        let previousProgress = previous.flatMap { quickStartRoute.firstIndex(of: $0).map { Double($0 + 1) / Double(quickStartRoute.count) } } ?? 0
        let nextProgress = next.flatMap { quickStartRoute.firstIndex(of: $0).map { Double($0 + 1) / Double(quickStartRoute.count) } } ?? 1
        return (previousProgress + nextProgress) / 2
    }

    static var noBackScreens: Set<OnboardingScreenID> {
        [.screen0, .screen1, .screen7B, .screen9, .screen16A, .screen16B, .screen17D]
    }
}

extension OnboardingScreenID {
    var analyticsName: String {
        switch self {
        case .screen0: return "legacy_signup_intro"
        case .screen1: return "welcome"
        case .screen2: return "legacy_problem"
        case .screen3: return "mechanism"
        case .screen4: return "legacy_prayer_frequency"
        case .screen5: return "legacy_phone_usage"
        case .screen6: return "prayer_selection"
        case .screen7A: return "goal_selection"
        case .screen7B: return "legacy_screen_time_insight"
        case .screen8: return "support_pace"
        case .screen9: return "legacy_plan_loading"
        case .screen10: return "personalized_plan"
        case .screen10A: return "legacy_plan_detail"
        case .screen11: return "legacy_notifications_permission"
        case .screen12: return "legacy_sound_setup"
        case .screen13: return "legacy_silent_mode_setup"
        case .screen14: return "legacy_location_permission"
        case .screen15: return "legacy_camera_permission"
        case .screen16: return "legacy_mat_setup"
        case .screen16A: return "legacy_lock_intro"
        case .screen16B: return "legacy_lock_setup"
        case .screen17: return "account"
        case .screen17A: return "legacy_sales_salah_is_powerful"
        case .screen17B: return "legacy_sales_future_habit"
        case .screen17C: return "legacy_sales_social_proof"
        case .screen17D: return "legacy_sales_free_to_try"
        case .screen17E: return "legacy_sales_trial_reminder"
        case .screen17F: return "legacy_sales_support_pitch"
        case .screen18: return "paywall"
        case .screen19: return "legacy_screen_19"
        case .screen20: return "legacy_screen_20"
        case .screen21: return "legacy_screen_21"
        case .screen22: return "legacy_screen_22"
        case .screen23: return "legacy_screen_23"
        case .screen24: return "legacy_screen_24"
        case .screen25A: return "legacy_screen_25a"
        case .screen25B: return "legacy_screen_25b"
        case .screen25: return "legacy_screen_25"
        case .screen26: return "legacy_screen_26"
        case .screen27: return "legacy_screen_27"
        case .screen28: return "legacy_screen_28"
        case .screen29: return "legacy_screen_29"
        case .screen30: return "legacy_screen_30"
        }
    }

    var funnelIndex: Int? {
        if let index = OnboardingRouter.quickStartRoute.firstIndex(of: self) { return index + 1 }
        return OnboardingScreenID.analyticsOrder.firstIndex(of: self).map { 100 + $0 }
    }
    private static let analyticsOrder: [OnboardingScreenID] = [.screen0, .screen1, .screen2, .screen3, .screen4, .screen5, .screen6, .screen7A, .screen7B, .screen8, .screen9, .screen10, .screen10A, .screen11, .screen12, .screen13, .screen14, .screen15, .screen16, .screen16A, .screen16B, .screen17, .screen17A, .screen17B, .screen17C, .screen17D, .screen17E, .screen17F, .screen18, .screen19, .screen20, .screen21, .screen22, .screen23, .screen24, .screen25A, .screen25B, .screen25, .screen26, .screen27, .screen28, .screen29, .screen30]
}
