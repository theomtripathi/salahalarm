//
//  OnboardingFlowViewModel.swift
//  Ramadan Pro
//

import Foundation
import SwiftUI
import CoreLocation
import Combine
import FirebaseAnalytics

@MainActor
final class OnboardingFlowViewModel: ObservableObject {
    @Published var currentScreen: OnboardingScreenID = .screen0 {
        didSet {
            progressValue = OnboardingRouter.progress(for: currentScreen)
            profile.lastCompletedScreen = currentScreen.rawValue
            saveLocal()
            guard analyticsTrackingActive, oldValue != currentScreen else { return }
            FunnelAnalytics.shared.transitionOnboarding(to: currentScreen, completed: pendingTransitionCompleted)
            pendingTransitionCompleted = false
        }
    }
    @Published var progressValue: Double? = nil
    @Published var profile = OnboardingProfile()
    @Published var derivedPlan = OnboardingDerivedPlan()
    @Published var isLoading = false
    @Published var loaderProgress: Double = 0.34
    @Published var todaySchedule: DailyPrayerSchedule?
    @Published var currentLocation: UserLocation?
    @Published var showEmailSignUp = false
    @Published var showLogin = false
    private var analyticsTrackingActive = false
    private var pendingTransitionCompleted = false

    let authViewModel: AuthViewModel
    private let persistence = OnboardingPersistenceService()

    init(authViewModel: AuthViewModel? = nil) {
        self.authViewModel = authViewModel ?? AuthViewModel.shared
        self.progressValue = OnboardingRouter.progress(for: currentScreen)
    }

    func advance() {
        if OnboardingRouter.variantDecisionNeeded(at: currentScreen) {
            FunnelAnalytics.shared.assignOnboardingVariantIfNeeded()
        }
        guard let nextScreen = nextScreen(after: currentScreen) else { return }
        FunnelAnalytics.shared.onboardingAction(action: "continue_tapped", screen: currentScreen)
        submitAnswers(for: currentScreen)
        AnalyticsLogger.logAnswerSubmitted(screen: currentScreen.rawValue)
        pendingTransitionCompleted = true
        if currentScreen == .screen10 { FunnelAnalytics.shared.onboardingQuestionnaireCompleted() }
        currentScreen = nextScreen
        AnalyticsLogger.logScreenView(screenID: nextScreen.rawValue)
    }

    func back() {
        guard !OnboardingRouter.noBackScreens.contains(currentScreen),
              let previous = OnboardingRouter.previous(before: currentScreen) else { return }
        FunnelAnalytics.shared.onboardingAction(action: "back_tapped", screen: currentScreen)
        pendingTransitionCompleted = false
        currentScreen = previous
        AnalyticsLogger.logScreenView(screenID: previous.rawValue)
    }

    func skipTo(_ screen: OnboardingScreenID) {
        guard screen != currentScreen else { return }
        FunnelAnalytics.shared.onboardingAction(action: "skip_tapped", screen: currentScreen)
        pendingTransitionCompleted = true
        if currentScreen == .screen10 { FunnelAnalytics.shared.onboardingQuestionnaireCompleted() }
        currentScreen = screen
        AnalyticsLogger.logScreenView(screenID: screen.rawValue)
    }

    private func submitAnswers(for screen: OnboardingScreenID) {
        let analytics = FunnelAnalytics.shared
        switch screen {
        case .screen6:
            analytics.onboardingAnswerSubmitted(questionID: "alarm_prayers", answers: profile.selectedAlarmPrayers.map(\.rawValue))
        case .screen7A:
            analytics.onboardingAnswerSubmitted(questionID: "goals", answers: profile.goals.map(\.rawValue))
        case .screen8:
            analytics.onboardingAnswerSubmitted(questionID: "support_pace", answers: [profile.commitmentLevel.rawValue])
            analytics.onboardingAnswerSubmitted(questionID: "alarm_strictness", answers: [profile.alarmStrictness.rawValue])
        case .screen12:
            analytics.onboardingAnswerSubmitted(questionID: "alarm_sound", answers: [AlarmSoundOption.analyticsID(for: profile.alarmSoundName)])
        default:
            break
        }
    }

    /// Call after saved-progress/auth resolution has selected the initial screen.
    func startAnalytics() {
        guard !analyticsTrackingActive else { return }
        analyticsTrackingActive = true
        FunnelAnalytics.shared.startOnboardingAnalytics(screen: currentScreen)
    }

    func pauseAnalytics() {
        analyticsTrackingActive = false
        FunnelAnalytics.shared.pauseOnboardingJourney()
    }

    func resumeAnalytics() {
        guard !analyticsTrackingActive else { return }
        analyticsTrackingActive = true
        FunnelAnalytics.shared.resumeOnboardingJourney()
    }

    private func nextScreen(after screen: OnboardingScreenID) -> OnboardingScreenID? {
        switch screen {
        case .screen16: return FirebaseAuthService.shared.isAuthenticated ? .screen18 : .screen17
        case .screen17: return .screen18
        default: return OnboardingRouter.next(after: screen)
        }
    }

    func setName(_ name: String) {
        profile.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        saveLocal()
    }

    func setAgeRange(_ range: AgeRange) {
        profile.ageRange = range
        saveLocal()
    }

    func setPrayerFrequency(_ frequency: PrayerFrequency) {
        profile.prayerFrequency = frequency
        saveLocal()
    }

    func setPhoneUsage(_ range: PhoneUsageRange) {
        profile.dailyPhoneUsageRange = range
        let stats = PhoneUsageCalculator.stats(for: range)
        derivedPlan.annualPhoneHours = stats.hours
        derivedPlan.annualPhoneDays = stats.days
        derivedPlan.lifetimePhoneYears = stats.years
        saveLocal()
    }

    func toggleGoal(_ goal: UserGoal) {
        if profile.goals.contains(goal) {
            profile.goals.removeAll { $0 == goal }
        } else if profile.goals.count < 3 {
            profile.goals.append(goal)
        }
        FunnelAnalytics.shared.onboardingSelectionChanged(questionID: "goals", selectionCount: profile.goals.count)
        saveLocal()
    }

    func toggleObstacle(_ obstacle: UserObstacle) {
        if profile.obstacles.contains(obstacle) {
            profile.obstacles.removeAll { $0 == obstacle }
        } else if profile.obstacles.count < 3 {
            profile.obstacles.append(obstacle)
        }
        saveLocal()
    }

    func setRelationship(_ state: RelationshipState) {
        profile.relationshipWithAllah = state
        saveLocal()
    }

    func toggleStruggle(_ struggle: DeeperStruggle) {
        if profile.deeperStruggles.contains(struggle) {
            profile.deeperStruggles.removeAll { $0 == struggle }
        } else {
            profile.deeperStruggles.append(struggle)
        }
        saveLocal()
    }

    func setBackground(_ background: MuslimBackground) {
        profile.muslimBackground = background
        saveLocal()
    }

    func setGender(_ gender: UserGender) {
        profile.gender = gender
        saveLocal()
    }

    func setCommitment(_ level: CommitmentLevel) {
        profile.commitmentLevel = level
        derivedPlan.commitmentProgressPct = level.progressPercentage
        derivedPlan.targetConsistencyDate = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
        finalizeDerivedPlan()
        FunnelAnalytics.shared.onboardingSelectionChanged(questionID: "support_pace", selectionCount: 1)
        saveLocal()
    }

    func toggleMissedPrayer(_ prayer: PrayerName) {
        if profile.missedPrayerFocus.contains(prayer) {
            profile.missedPrayerFocus.removeAll { $0 == prayer }
        } else {
            profile.missedPrayerFocus.append(prayer)
        }
        saveLocal()
    }

    func setSelectedAlarmPrayers(_ prayers: [PrayerName]) {
        profile.selectedAlarmPrayers = prayers
        saveLocal()
    }

    func toggleSelectedAlarmPrayer(_ prayer: PrayerName) {
        if profile.selectedAlarmPrayers.contains(prayer) {
            profile.selectedAlarmPrayers.removeAll { $0 == prayer }
        } else {
            profile.selectedAlarmPrayers.append(prayer)
        }

        if profile.selectedAlarmPrayers.isEmpty {
            profile.selectedAlarmPrayers = [.fajr]
        }

        saveLocal()
    }

    func setAlarmStrictness(_ strictness: AlarmStrictness) {
        profile.alarmStrictness = strictness
        saveLocal()
    }

    func setAlarmSound(_ soundName: String) {
        profile.alarmSoundName = soundName
        AlarmViewModel.shared.setSound(soundName)
        saveLocal()
    }

    func setCameraPermission(_ state: PermissionState) {
        profile.cameraPermissionState = state
        saveLocal()
    }

    func setMatSetupCompleted(_ completed: Bool) {
        profile.matSetupCompleted = completed
        saveLocal()
    }

    func toggleApp(_ bundleId: String) {
        if profile.selectedDistractingApps.contains(bundleId) {
            profile.selectedDistractingApps.removeAll { $0 == bundleId }
        } else {
            profile.selectedDistractingApps.append(bundleId)
        }
        profile.screenTimePermissionState = .granted
        saveLocal()
    }

    func setNotificationsPermission(_ granted: Bool) {
        profile.notificationsPermissionState = granted ? .granted : .denied
        FunnelAnalytics.shared.onboardingAction(action: "permission_result", screen: currentScreen, permissionReason: granted ? "granted" : "denied")
        saveLocal()
    }

    func skipNotificationsPermission() {
        profile.notificationsPermissionState = .skipped
        FunnelAnalytics.shared.onboardingAction(action: "skip_tapped", screen: currentScreen)
        saveLocal()
    }

    /// The next selected prayer that can still ring, once location has loaded.
    /// When every selected prayer has passed today, it is tomorrow's earliest one
    /// (today's time shifted a day, which is within minutes of tomorrow's).
    var firstAlarm: (prayer: PrayerName, time: Date)? {
        guard let schedule = todaySchedule else { return nil }
        let now = Date()
        let alarms = profile.selectedAlarmPrayers
            .map { prayer -> (prayer: PrayerName, time: Date) in
                switch prayer {
                case .fajr: return (prayer, schedule.fajr)
                case .dhuhr: return (prayer, schedule.dhuhr)
                case .asr: return (prayer, schedule.asr)
                case .maghrib: return (prayer, schedule.maghrib)
                case .isha: return (prayer, schedule.isha)
                }
            }
        if let upcoming = alarms.filter({ $0.time > now }).min(by: { $0.time < $1.time }) {
            return upcoming
        }
        guard let earliest = alarms.min(by: { $0.time < $1.time }),
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: earliest.time) else { return nil }
        return (earliest.prayer, tomorrow)
    }

    /// Re-schedules after notification permission is granted later in the flow.
    func scheduleSelectedPrayerReminders() {
        guard let schedule = todaySchedule else { return }
        let selectedTypes = Set(profile.selectedAlarmPrayers.map { prayer -> PrayerType in
            switch prayer {
            case .fajr: return .fajr
            case .dhuhr: return .dhuhr
            case .asr: return .asr
            case .maghrib: return .maghrib
            case .isha: return .isha
            }
        })
        let filteredTimes = schedule.allPrayerTimes.filter {
            $0.type != .imsak && selectedTypes.contains($0.type)
        }
        NotificationManager.shared.scheduleFiveDailyPrayerReminders(times: filteredTimes)
    }

    func setLocationPermission(_ state: PermissionState) {
        profile.locationPermissionState = state
        let reason: String
        switch state {
        case .granted: reason = "granted"
        case .denied: reason = "denied"
        case .notDetermined: reason = "not_determined"
        case .skipped: reason = "unavailable"
        }
        FunnelAnalytics.shared.onboardingAction(action: "permission_result", screen: currentScreen, permissionReason: reason)
        saveLocal()
    }

    func finalizeDerivedPlan() {
        derivedPlan.primaryGoal = profile.goals.first?.displayLabel ?? ""
        derivedPlan.topGoals = Array(profile.goals.prefix(3)).map(\.displayLabel)
        derivedPlan.alarmCount = profile.selectedAlarmPrayers.count
        derivedPlan.alarmPrayerNames = profile.selectedAlarmPrayers.map(\.displayName)
        derivedPlan.topObstacles = Array(profile.obstacles.prefix(3)).map(\.displayLabel)
        derivedPlan.currentHabitSummary = profile.prayerFrequency.habitSummary
        derivedPlan.strengthStatement = buildStrengthStatement()
        if derivedPlan.targetConsistencyDate < Date() {
            derivedPlan.targetConsistencyDate = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
        }
    }

    func buildStrengthStatement() -> String {
        switch profile.commitmentLevel {
        case .extremelyCommitted:
            return "You are deeply committed to protecting salah and ready for a disciplined routine."
        case .veryCommitted:
            return "You are motivated to improve your salah consistency."
        case .committed:
            return "You are taking meaningful steps toward a stronger salah habit."
        case .startingJourney:
            return "You are open to building the habit one prayer at a time."
        case .justExploring:
            return "You are curious and willing to explore what consistency could look like."
        case .unset:
            return "You are taking a sincere step toward more consistent prayer."
        }
    }

    func confirmFirstPrayer() {
        profile.firstPrayerCompletedAt = Date()
        saveLocal()
        AnalyticsLogger.logFirstPrayerConfirmed()
        Task {
            await persistence.saveToFirestore(profile: profile, plan: derivedPlan)
        }
    }

    func completeOnboarding() {
        profile.onboardingCompletedAt = Date()
        AlarmViewModel.shared.applyOnboardingPreferences(
            selectedPrayers: profile.selectedAlarmPrayers,
            strictness: profile.alarmStrictness,
            soundName: profile.alarmSoundName,
            matSetupCompleted: profile.matSetupCompleted
        )
        AppState.shared.onboardingComplete = true
        FunnelAnalytics.shared.onboardingFinished()
        saveLocal()
        AnalyticsLogger.logCompleted()
        Task {
            await persistence.saveToFirestore(profile: profile, plan: derivedPlan)
        }
    }

    func saveLocal() {
        persistence.saveLocal(profile: profile, plan: derivedPlan, lastScreen: currentScreen.rawValue)
    }

    func loadSavedProgress() -> OnboardingScreenID? {
        guard let cache = persistence.loadLocal() else { return nil }
        profile = cache.profile
        derivedPlan = cache.plan
        progressValue = OnboardingRouter.progress(for: currentScreen)
        return OnboardingScreenID(rawValue: cache.lastScreen)
    }

    func mergeProfileAfterAuth() {
        Task {
            await persistence.saveToFirestore(profile: profile, plan: derivedPlan)
        }
    }

    func loadLocationAndPrayerTimes() async {
        isLoading = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            LocationManager.shared.startUpdatingLocation { [weak self] location in
                Task { @MainActor in
                    defer {
                        self?.isLoading = false
                        continuation.resume()
                    }
                    guard let self, let location else { return }
                    self.currentLocation = location
                    let schedule = PrayerTimesCalculator.calculatePrayerTimes(for: Date(), location: location)
                    self.todaySchedule = schedule

                    // Only schedule notifications for prayers the user selected
                    self.scheduleSelectedPrayerReminders()

                    // Apply alarm preferences immediately so the alarm engine knows
                    // which prayers are enabled without waiting for completeOnboarding
                    AlarmViewModel.shared.applyOnboardingPreferences(
                        selectedPrayers: self.profile.selectedAlarmPrayers,
                        strictness: self.profile.alarmStrictness,
                        soundName: self.profile.alarmSoundName,
                        matSetupCompleted: self.profile.matSetupCompleted
                    )
                }
            }
        }
    }

}

enum AnalyticsLogger {
    static func logScreenView(screenID: String) {
        Analytics.logEvent("onboarding_screen_viewed", parameters: ["screen_id": screenID as NSString])
    }

    static func logAnswerSubmitted(screen: String) {
        Analytics.logEvent("onboarding_answer_submitted", parameters: ["screen_id": screen as NSString])
    }

    static func logFirstPrayerConfirmed() {
        Analytics.logEvent("onboarding_first_prayer_confirmed", parameters: nil)
    }

    static func logCompleted() {
        Analytics.logEvent("onboarding_completed", parameters: nil)
    }
}
