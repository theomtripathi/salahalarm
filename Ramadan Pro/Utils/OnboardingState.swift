//
//  OnboardingState.swift
//  Ramadan Pro
//

import Foundation
import SwiftUI
import Combine

final class OnboardingState: ObservableObject {
    static let shared = OnboardingState()

    enum OnboardingStep: Int, CaseIterable {
        case splash = 0
        case login = 1
        case signIn = 2
        case locationPermission = 3
        case focusSelection = 4
        case impactIntroduction = 5
        case challengeIdentification = 6
        case widgetShowcase = 7
        case customizationLoader = 8
        case mainPaywall = 9
        case delayedDiscountPaywall = 10
        case donationSuccess = 11
    }

    @Published var currentStep: OnboardingStep = .login
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
            AppState.shared.onboardingComplete = hasCompletedOnboarding
        }
    }
    @Published var selectedFocus: FocusOption?
    @Published var selectedChallenge: ChallengeOption?
    @Published var subscriptionDonationAmount: Int = 0
    @Published var paywallViewCount: Int = 0
    @Published var shouldShowDelayedDiscount: Bool = false

    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func incrementPaywallViewCount() {
        paywallViewCount += 1
        UserDefaults.standard.set(paywallViewCount, forKey: "paywallViewCount")
    }

    func resetPaywallTracking() {
        paywallViewCount = 0
        shouldShowDelayedDiscount = false
        UserDefaults.standard.set(0, forKey: "paywallViewCount")
    }

    func nextStep() {
        if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    func previousStep() {
        if let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            currentStep = previous
        }
    }

    func skipToStep(_ step: OnboardingStep) {
        currentStep = step
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
