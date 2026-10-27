//
//  SalahLockMonitorExtension.swift
//  SalahLockMonitor
//
//  DeviceActivityMonitor extension: iOS launches this at the prayer-time
//  intervals the main app registers, so the shield goes up at prayer time
//  even when SalahAlarm itself was force-quit.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class SalahLockMonitorExtension: DeviceActivityMonitor {

    /// Must match the store name used by AppLockManager in the main app —
    /// named stores are shared between the app and its extensions.
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("salahAlarmPrayerLock"))

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: "group.ramadan-pro.sonn")
    }

    /// Mirror of DailyPrayerLog with just the flags we need.
    private struct SharedPrayerLog: Codable {
        var fajr = false
        var dhuhr = false
        var asr = false
        var maghrib = false
        var isha = false

        func isConfirmed(_ prayerRawValue: String) -> Bool {
            switch prayerRawValue {
            case "fajr": return fajr
            case "dhuhr": return dhuhr
            case "asr": return asr
            case "maghrib": return maghrib
            case "isha": return isha
            default: return false
            }
        }
    }

    // MARK: - DeviceActivityMonitor

    /// Activity names are "salahlock.<prayer>", e.g. "salahlock.fajr".
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        let prayer = activity.rawValue.replacingOccurrences(of: "salahlock.", with: "")

        // Master switch (defaults to enabled when the key was never written)
        if let defaults, defaults.object(forKey: "salahlock_lock_enabled") != nil,
           defaults.bool(forKey: "salahlock_lock_enabled") == false {
            return
        }

        // Already confirmed (user prayed early) — nothing to lock
        if todaysLog().isConfirmed(prayer) {
            return
        }

        guard let selection = loadSelection() else { return }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    /// The prayer window ended (next prayer arrived / day ended) — release the
    /// shield so an unconfirmed prayer can't lock the user out forever.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.clearAllSettings()
    }

    // MARK: - Shared state

    private func loadSelection() -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: "salahlock_activity_selection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }
        let isEmpty = selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
        return isEmpty ? nil : selection
    }

    private func todaysLog() -> SharedPrayerLog {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "salahlock_prayer_log_\(formatter.string(from: Date()))"
        guard let data = defaults?.data(forKey: key),
              let log = try? JSONDecoder().decode(SharedPrayerLog.self, from: data) else {
            return SharedPrayerLog()
        }
        return log
    }
}
