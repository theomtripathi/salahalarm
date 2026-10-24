//
//  AlarmViewModel.swift
//  Ramadan Pro
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
final class AlarmViewModel: ObservableObject {
    static let shared = AlarmViewModel()

    struct ScheduledAlarm: Identifiable, Equatable {
        let prayer: PrayerName
        let scheduledTime: Date

        var id: String { "\(prayer.rawValue)-\(scheduledTime.timeIntervalSince1970)" }
    }

    struct ActiveAlarmPresentation: Identifiable, Equatable {
        let prayer: PrayerName
        let scheduledTime: Date

        var id: String { "\(prayer.rawValue)-\(scheduledTime.timeIntervalSince1970)" }
    }

    @Published var settings: AlarmSettings
    @Published var nextScheduledAlarm: ScheduledAlarm?
    @Published var activeAlarm: ActiveAlarmPresentation?
    @Published var showSettingsSheet = false
    @Published var showSoundSetupSheet = false
    @Published var showSubscriptionPaywall = false
    @Published var silentWarningDismissed: Bool
    @Published private(set) var logs: [AlarmLog]
    @Published private(set) var subscriptionStatus: SubscriptionStatus = SubscriptionStatus.load()

    private let settingsKey = "sa_alarm_settings"
    private let logsKey = "sa_alarm_logs"
    private let bannerKey = "silentBannerDismissed"
    private let lastTriggeredKey = "sa_last_triggered_alarm_id"
    private var cancellables = Set<AnyCancellable>()
    private let audioService = AlarmAudioService.shared
    private var currentSchedule: DailyPrayerSchedule?

    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AlarmSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AlarmSettings()
        }

        if let data = UserDefaults.standard.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([AlarmLog].self, from: data) {
            logs = decoded
        } else {
            logs = []
        }

        silentWarningDismissed = UserDefaults.standard.bool(forKey: bannerKey)
        bindSubscriptionStatus()
        enforceSubscriptionAccess()
    }

    var criticalAlertEntitlementActive: Bool { false }

    var hasAlarmAccess: Bool {
        subscriptionStatus.isActive && !subscriptionStatus.isExpired
    }

    var shouldShowSilentWarning: Bool {
        hasAlarmAccess && !criticalAlertEntitlementActive && !silentWarningDismissed
    }

    func syncSchedule(_ schedule: DailyPrayerSchedule?, now: Date = Date()) {
        guard hasAlarmAccess, settings.alarmsEnabled, let schedule else {
            nextScheduledAlarm = nil
            activeAlarm = nil
            return
        }

        let upcoming = upcomingAlarm(from: schedule, now: now)
        nextScheduledAlarm = upcoming
        evaluateAlarmTrigger(now: now)

        // Cache schedule for notification rescheduling
        if currentSchedule == nil || !Calendar.current.isDateInToday(currentSchedule!.fajr) {
            currentSchedule = schedule
            rescheduleNotifications(schedule: schedule)
        }
    }

    func setAlarmsEnabled(_ isEnabled: Bool) {
        guard ensureAlarmAccessForInteraction() || !isEnabled else { return }
        settings.alarmsEnabled = isEnabled
        saveSettings()
        TrialJourneyTracker.shared.recordAlarmConfigured(status: subscriptionStatus, settings: settings)
        if !isEnabled {
            activeAlarm = nil
            audioService.stop()
            NotificationManager.shared.cancelAllAlarmNotifications()
        } else if let schedule = currentSchedule {
            rescheduleNotifications(schedule: schedule)
        }
    }

    func setStrictness(_ strictness: AlarmStrictness) {
        guard ensureAlarmAccessForInteraction() else { return }
        settings.strictness = strictness
        saveSettings()
    }

    func setSound(_ soundName: String) {
        guard ensureAlarmAccessForInteraction() else { return }
        settings.soundName = soundName
        saveSettings()
        // Reschedule notifications so the new sound is used
        if let schedule = currentSchedule {
            rescheduleNotifications(schedule: schedule)
        }
    }

    func setPrayerEnabled(_ isEnabled: Bool, for prayer: PrayerName) {
        guard ensureAlarmAccessForInteraction() || !isEnabled else { return }
        settings.setEnabled(isEnabled, for: prayer)
        saveSettings()
        TrialJourneyTracker.shared.recordAlarmConfigured(status: subscriptionStatus, settings: settings)
        if let schedule = currentSchedule {
            rescheduleNotifications(schedule: schedule)
        }
    }

    func applyOnboardingPreferences(
        selectedPrayers: [PrayerName],
        strictness: AlarmStrictness,
        soundName: String,
        matSetupCompleted: Bool
    ) {
        settings.strictness = strictness
        settings.soundName = soundName
        settings.matSetupCompleted = matSetupCompleted

        for prayer in PrayerName.allCases {
            settings.setEnabled(selectedPrayers.contains(prayer), for: prayer)
        }

        settings.alarmsEnabled = !selectedPrayers.isEmpty
        saveSettings()
        TrialJourneyTracker.shared.recordAlarmConfigured(status: subscriptionStatus, settings: settings)
        if let schedule = currentSchedule {
            rescheduleNotifications(schedule: schedule)
        }
    }

    func dismissSilentWarning() {
        silentWarningDismissed = true
        UserDefaults.standard.set(true, forKey: bannerKey)
    }

    /// Called by NotificationDelegate when the app is opened via a prayer alarm notification.
    /// Starts the looping audio and shows the full-screen alarm UI.
    func triggerAlarmFromNotification(prayer: PrayerName, scheduledTime: Date) {
        guard settings.alarmsEnabled, settings.isEnabled(for: prayer) else { return }
        // Avoid double-triggering the same alarm
        let triggerID = "\(prayer.rawValue)-\(Int(scheduledTime.timeIntervalSince1970 / 60) * 60)"
        if UserDefaults.standard.string(forKey: lastTriggeredKey) == triggerID { return }
        UserDefaults.standard.set(triggerID, forKey: lastTriggeredKey)

        activeAlarm = ActiveAlarmPresentation(prayer: prayer, scheduledTime: scheduledTime)
        audioService.startAlarmLoop(soundName: settings.soundName, volume: settings.volume)
        appendLog(prayer: prayer, scheduledTime: scheduledTime, dismissalMethod: .ringing)
    }

    func triggerTestAlarm(prayer: PrayerName = .fajr) {
        guard ensureAlarmAccessForInteraction() else { return }
        activeAlarm = ActiveAlarmPresentation(prayer: prayer, scheduledTime: Date())
        audioService.startAlarmLoop(soundName: settings.soundName, volume: settings.volume)
        appendLog(prayer: prayer, scheduledTime: Date(), dismissalMethod: .ringing)
    }

    func dismissWithMatScan() {
        guard let activeAlarm else { return }
        audioService.stop()
        appendLog(prayer: activeAlarm.prayer, scheduledTime: activeAlarm.scheduledTime, dismissalMethod: .matScan)
        self.activeAlarm = nil
    }

    func dismissManually() {
        guard let activeAlarm else { return }
        audioService.stop()
        appendLog(prayer: activeAlarm.prayer, scheduledTime: activeAlarm.scheduledTime, dismissalMethod: .manual)
        self.activeAlarm = nil
    }

    func dismissAsMissed() {
        guard let activeAlarm else { return }
        audioService.stop()
        appendLog(prayer: activeAlarm.prayer, scheduledTime: activeAlarm.scheduledTime, dismissalMethod: .missed)
        self.activeAlarm = nil
    }

    func snoozeActiveAlarm() {
        guard let activeAlarm else { return }
        audioService.stop()
        appendLog(prayer: activeAlarm.prayer, scheduledTime: activeAlarm.scheduledTime, dismissalMethod: .snoozed)
        self.activeAlarm = ActiveAlarmPresentation(
            prayer: activeAlarm.prayer,
            scheduledTime: Date().addingTimeInterval(5 * 60)
        )
    }

    private func upcomingAlarm(from schedule: DailyPrayerSchedule, now: Date) -> ScheduledAlarm? {
        let prayers: [(PrayerName, Date)] = [
            (.fajr, schedule.fajr),
            (.dhuhr, schedule.dhuhr),
            (.asr, schedule.asr),
            (.maghrib, schedule.maghrib),
            (.isha, schedule.isha)
        ]

        return prayers
            .filter { settings.isEnabled(for: $0.0) && $0.1 > now }
            .map { ScheduledAlarm(prayer: $0.0, scheduledTime: $0.1) }
            .first
    }

    private func evaluateAlarmTrigger(now: Date) {
        guard settings.alarmsEnabled, let nextScheduledAlarm else { return }
        let triggerWindow = abs(nextScheduledAlarm.scheduledTime.timeIntervalSince(now))
        guard triggerWindow <= 60 else { return }

        let triggerID = nextScheduledAlarm.id
        if UserDefaults.standard.string(forKey: lastTriggeredKey) == triggerID {
            return
        }

        UserDefaults.standard.set(triggerID, forKey: lastTriggeredKey)
        activeAlarm = ActiveAlarmPresentation(
            prayer: nextScheduledAlarm.prayer,
            scheduledTime: nextScheduledAlarm.scheduledTime
        )
        audioService.startAlarmLoop(soundName: settings.soundName, volume: settings.volume)
        appendLog(
            prayer: nextScheduledAlarm.prayer,
            scheduledTime: nextScheduledAlarm.scheduledTime,
            dismissalMethod: .ringing
        )
    }

    private func appendLog(prayer: PrayerName, scheduledTime: Date, dismissalMethod: AlarmLog.DismissalMethod) {
        let log = AlarmLog(
            prayer: prayer,
            scheduledTime: scheduledTime,
            firedAt: Date(),
            dismissedAt: dismissalMethod == .ringing ? nil : Date(),
            dismissalMethod: dismissalMethod
        )
        logs.insert(log, at: 0)
        logs = Array(logs.prefix(30))
        saveLogs()
    }

    private func rescheduleNotifications(schedule: DailyPrayerSchedule) {
        guard settings.alarmsEnabled, hasAlarmAccess else {
            NotificationManager.shared.cancelAllAlarmNotifications()
            return
        }
        let enabled = Set(PrayerName.allCases.filter { settings.isEnabled(for: $0) })
        NotificationManager.shared.schedulePrayerAlarms(
            schedule: schedule,
            tomorrowSchedule: nil,
            enabledPrayers: enabled,
            soundName: settings.soundName
        )
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func saveLogs() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: logsKey)
        }
    }

    private func bindSubscriptionStatus() {
        RevenueCatService.shared.$subscriptionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.subscriptionStatus = status
                status.save()
                self.enforceSubscriptionAccess()
            }
            .store(in: &cancellables)
    }

    private func ensureAlarmAccessForInteraction() -> Bool {
        guard hasAlarmAccess else {
            showSettingsSheet = false
            showSubscriptionPaywall = true
            enforceSubscriptionAccess()
            return false
        }
        return true
    }

    private func enforceSubscriptionAccess() {
        guard !hasAlarmAccess else { return }

        if settings.alarmsEnabled {
            settings.alarmsEnabled = false
            saveSettings()
        }

        nextScheduledAlarm = nil
        activeAlarm = nil
        audioService.stop()
    }
}
