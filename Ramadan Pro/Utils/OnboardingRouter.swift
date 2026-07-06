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
    case screen17
    case screen17A
    case screen17B
    case screen17C
    case screen17D
    case screen17E
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
    static func next(after screen: OnboardingScreenID) -> OnboardingScreenID? {
        switch screen {
        case .screen0: return .screen1
        case .screen1: return .screen2
        case .screen2: return .screen3
        case .screen3: return .screen4
        case .screen4: return .screen5
        case .screen5: return .screen6
        case .screen6: return .screen7A
        case .screen7A: return .screen7B
        case .screen7B: return .screen8
        case .screen8: return .screen9
        case .screen9: return .screen10
        case .screen10: return .screen10A
        case .screen10A: return .screen11
        case .screen11: return .screen12
        case .screen12: return .screen13
        case .screen13: return .screen14
        case .screen14: return .screen15
        case .screen15: return .screen16
        case .screen16: return .screen17
        case .screen17: return .screen17A
        case .screen17A: return .screen17B
        case .screen17B: return .screen18
        case .screen17C: return .screen18
        case .screen17D: return .screen18
        case .screen17E: return .screen18
        case .screen18: return nil
        default: return nil
        }
    }

    static func previous(before screen: OnboardingScreenID) -> OnboardingScreenID? {
        let all = OnboardingScreenID.allCases
        guard let index = all.firstIndex(of: screen), index > 0 else { return nil }
        return all[index - 1]
    }

    static func progress(for screen: OnboardingScreenID) -> Double? {
        switch screen {
        case .screen4: return 0.10
        case .screen5: return 0.20
        case .screen6: return 0.30
        case .screen7A: return 0.40
        case .screen8: return 0.55
        default: return nil
        }
    }

    static var noBackScreens: Set<OnboardingScreenID> {
        [.screen0, .screen1, .screen7B, .screen9, .screen17D]
    }
}
