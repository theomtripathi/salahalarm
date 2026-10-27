//
//  AppLockManager.swift
//  Ramadan Pro
//
//  Screen Time based prayer lock. Shields the user's selected apps from the
//  moment an enforced prayer's time arrives until they confirm "I've prayed".
//

import Foundation
import Combine
import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    // MARK: - Published state

    @Published private(set) var isAuthorized: Bool = false

    /// Master switch for the prayer lock feature.
    @Published var lockEnabled: Bool {
        didSet {
            defaults?.set(lockEnabled, forKey: Keys.lockEnabled)
            evaluate()
        }
    }

    /// Prayers that trigger the lock when missed. Defaults to Fajr only.
    @Published var enforcedPrayers: Set<PrayerName> {
        didSet {
            defaults?.set(enforcedPrayers.map(\.rawValue), forKey: Keys.enforcedPrayers)
            evaluate()
        }
    }

    /// The apps / categories the user chose to lock.
    @Published var selection: FamilyActivitySelection {
        didSet {
            persistSelection()
            evaluate()
        }
    }

    /// The prayer currently keeping apps locked, nil when unlocked.
    @Published private(set) var activeLockPrayer: PrayerName?

    // MARK: - Private

    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("salahAlarmPrayerLock"))
    private let activityCenter = DeviceActivityCenter()
    private let defaults = WidgetConfig.sharedUserDefaults
    private var cachedSchedule: DailyPrayerSchedule?
    private var cachedLog = DailyPrayerLog()
    /// Fingerprint of the last DeviceActivity registration, so we don't
    /// re-submit identical schedules on every 15s tick.
    private var monitoredFingerprint: String?

    private enum Keys {
        static let lockEnabled = "salahlock_lock_enabled"
        static let enforcedPrayers = "salahlock_enforced_prayers"
        static let activitySelection = "salahlock_activity_selection"
    }

    private init() {
        let defaults = WidgetConfig.sharedUserDefaults
        lockEnabled = defaults?.object(forKey: Keys.lockEnabled) as? Bool ?? true

        if let raw = defaults?.stringArray(forKey: Keys.enforcedPrayers) {
            enforcedPrayers = Set(raw.compactMap(PrayerName.init(rawValue:)))
        } else {
            enforcedPrayers = [.fajr]
        }

        if let data = defaults?.data(forKey: Keys.activitySelection),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        } else {
            selection = FamilyActivitySelection()
        }

        refreshAuthorizationStatus()
    }

    // MARK: - Authorization

    func refreshAuthorizationStatus() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
            evaluate()
            return isAuthorized
        } catch {
            DebugLogger.logError("Screen Time authorization failed: \(error)")
            refreshAuthorizationStatus()
            return false
        }
    }

    // MARK: - Inputs

    /// Feed the manager the latest schedule + prayer log, then re-evaluate the shield.
    func update(schedule: DailyPrayerSchedule?, log: DailyPrayerLog, now: Date = Date()) {
        cachedSchedule = schedule
        cachedLog = log
        evaluate(now: now)
    }

    /// Lightweight refresh when only the log changed (e.g. after "I've prayed").
    func refreshLog(_ log: DailyPrayerLog) {
        cachedLog = log
        evaluate()
    }

    /// Self-sufficient evaluation for background wake-ups (silent-audio loop,
    /// BGAppRefreshTask, notification delegate). Rebuilds today's schedule from
    /// the saved location and reads the prayer log from the shared container,
    /// so it works even when no view has fed us fresh data.
    func evaluateFromSavedState(now: Date = Date()) {
        if cachedSchedule == nil || !Calendar.current.isDate(cachedSchedule!.date, inSameDayAs: now) {
            if let location = WidgetConfig.loadLocation() {
                cachedSchedule = PrayerTimesCalculator.calculatePrayerTimes(for: now, location: location)
            }
        }
        let todayKey = DateFormatter.yyyyMMdd.string(from: now)
        if let log = WidgetConfig.loadPrayerLog(for: todayKey, as: DailyPrayerLog.self) {
            cachedLog = log
        }
        evaluate(now: now)
    }

    // MARK: - Selection helpers

    var hasSelection: Bool {
        !(selection.applicationTokens.isEmpty
          && selection.categoryTokens.isEmpty
          && selection.webDomainTokens.isEmpty)
    }

    var selectionSummary: String {
        var parts: [String] = []
        if !selection.applicationTokens.isEmpty {
            parts.append("\(selection.applicationTokens.count) app\(selection.applicationTokens.count == 1 ? "" : "s")")
        }
        if !selection.categoryTokens.isEmpty {
            parts.append("\(selection.categoryTokens.count) categor\(selection.categoryTokens.count == 1 ? "y" : "ies")")
        }
        if !selection.webDomainTokens.isEmpty {
            parts.append("\(selection.webDomainTokens.count) website\(selection.webDomainTokens.count == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "No apps selected" : parts.joined(separator: ", ")
    }

    func toggleEnforced(_ prayer: PrayerName) {
        if enforcedPrayers.contains(prayer) {
            enforcedPrayers.remove(prayer)
        } else {
            enforcedPrayers.insert(prayer)
        }
    }

    private func persistSelection() {
        guard let encoded = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(encoded, forKey: Keys.activitySelection)
    }

    // MARK: - Shield evaluation

    /// Re-evaluates whether the shield should be up right now.
    /// Rule: for the enforced prayer whose window is active (prayer time has
    /// arrived and the next prayer hasn't), apps stay locked until the user
    /// confirms that prayer.
    func evaluate(now: Date = Date()) {
        guard lockEnabled, isAuthorized, hasSelection else {
            setLocked(nil)
            stopDeviceActivityMonitoring()
            return
        }
        guard let schedule = cachedSchedule,
              Calendar.current.isDate(schedule.date, inSameDayAs: now) else {
            setLocked(nil)
            return
        }

        syncDeviceActivityMonitoring(schedule: schedule, now: now)

        let prayers: [(PrayerName, Date)] = [
            (.fajr, schedule.fajr),
            (.dhuhr, schedule.dhuhr),
            (.asr, schedule.asr),
            (.maghrib, schedule.maghrib),
            (.isha, schedule.isha)
        ]

        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        var blocking: PrayerName?
        for (index, entry) in prayers.enumerated() {
            let (prayer, time) = entry
            let windowEnd = index + 1 < prayers.count ? prayers[index + 1].1 : endOfDay
            guard now >= time, now < windowEnd else { continue }
            if enforcedPrayers.contains(prayer) && !cachedLog.isConfirmed(prayer) {
                blocking = prayer
            }
            break
        }

        setLocked(blocking)
    }

    private func setLocked(_ prayer: PrayerName?) {
        if activeLockPrayer != prayer {
            activeLockPrayer = prayer
            DebugLogger.log(prayer.map { "AppLock shield ON for \($0.displayName)" } ?? "AppLock shield OFF")
        }

        if prayer != nil {
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil
                : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        } else {
            store.clearAllSettings()
        }
    }

    // MARK: - DeviceActivity registration

    /// Registers the enforced prayer windows with iOS. The SalahLockMonitor
    /// extension then raises the shield at each interval start even when the
    /// app is not running (including force-quit).
    private func syncDeviceActivityMonitoring(schedule: DailyPrayerSchedule, now: Date) {
        let dayKey = DateFormatter.yyyyMMdd.string(from: schedule.date)
        let fingerprint = "\(dayKey)|\(enforcedPrayers.map(\.rawValue).sorted().joined(separator: ","))"
        guard fingerprint != monitoredFingerprint else { return }

        activityCenter.stopMonitoring()

        let calendar = Calendar.current
        let prayers: [(PrayerName, Date)] = [
            (.fajr, schedule.fajr),
            (.dhuhr, schedule.dhuhr),
            (.asr, schedule.asr),
            (.maghrib, schedule.maghrib),
            (.isha, schedule.isha)
        ]
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: schedule.date) ?? schedule.date

        for (index, entry) in prayers.enumerated() {
            let (prayer, start) = entry
            guard enforcedPrayers.contains(prayer) else { continue }
            let end = index + 1 < prayers.count ? prayers[index + 1].1 : endOfDay
            // DeviceActivity requires intervals of at least 15 minutes
            guard end.timeIntervalSince(start) >= 15 * 60 else { continue }

            let activitySchedule = DeviceActivitySchedule(
                intervalStart: calendar.dateComponents([.hour, .minute], from: start),
                intervalEnd: calendar.dateComponents([.hour, .minute], from: end),
                repeats: true
            )
            do {
                try activityCenter.startMonitoring(
                    DeviceActivityName("salahlock.\(prayer.rawValue)"),
                    during: activitySchedule
                )
            } catch {
                DebugLogger.logError("DeviceActivity monitoring failed for \(prayer.rawValue): \(error)")
            }
        }

        monitoredFingerprint = fingerprint
        DebugLogger.log("AppLock DeviceActivity schedules registered (\(enforcedPrayers.count) prayers)")
    }

    private func stopDeviceActivityMonitoring() {
        guard monitoredFingerprint != nil else { return }
        activityCenter.stopMonitoring()
        monitoredFingerprint = nil
    }
}
