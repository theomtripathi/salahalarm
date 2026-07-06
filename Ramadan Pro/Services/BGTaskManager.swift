//
//  BGTaskManager.swift
//  Ramadan Pro
//
//  Registers and handles BGAppRefreshTask to recalculate prayer times
//  and reschedule alarm notifications — even when the app is killed.
//

import Foundation
import BackgroundTasks
import UserNotifications

class BGTaskManager {
    static let shared = BGTaskManager()
    static let refreshTaskID = "com.ramadanpro.alarm.refresh"

    private init() {}

    // MARK: - Registration (call once at app launch in AppDelegate)

    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleRefreshTask(refreshTask)
        }
        print("✅ BGTaskManager: Registered background refresh task")
    }

    // MARK: - Scheduling

    /// Schedule the next background refresh.
    /// iOS decides the exact execution time — we request "as soon as possible"
    /// and iOS balances it against battery and usage patterns.
    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        // Ask to run within the next hour — iOS will pick the best time
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ BGTaskManager: Scheduled next background refresh in ~1hr")
        } catch {
            print("⚠️ BGTaskManager: Failed to schedule refresh — \(error.localizedDescription)")
        }
    }

    // MARK: - Task Handler

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        print("🔄 BGTaskManager: Background refresh task started")

        // Schedule the next one immediately so we never miss a future prayer
        scheduleNextRefresh()

        // Set expiration handler — iOS may kill us early
        task.expirationHandler = {
            print("⚠️ BGTaskManager: Task expired before completion")
            task.setTaskCompleted(success: false)
        }

        // Perform the refresh on a background queue
        Task {
            await refreshPrayerAlarmsFromSavedLocation()
            task.setTaskCompleted(success: true)
            print("✅ BGTaskManager: Background refresh completed")
        }
    }

    // MARK: - Prayer Time Refresh

    private func refreshPrayerAlarmsFromSavedLocation() async {
        // Load saved location from UserDefaults (set by PrayerTimesViewModel)
        guard let data = UserDefaults.standard.data(forKey: "saved_user_location"),
              let location = try? JSONDecoder().decode(UserLocation.self, from: data) else {
            print("⚠️ BGTaskManager: No saved location — skipping alarm reschedule")
            return
        }

        let today = Date()
        let calendar = Calendar.current

        // Recalculate prayer times for today
        let todaySchedule = PrayerTimesCalculator.calculatePrayerTimes(for: today, location: location)

        // Recalculate for tomorrow
        let tomorrowSchedule: DailyPrayerSchedule?
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            tomorrowSchedule = PrayerTimesCalculator.calculatePrayerTimes(for: tomorrow, location: location)
        } else {
            tomorrowSchedule = nil
        }

        // Load current alarm settings
        guard let settingsData = UserDefaults.standard.data(forKey: "sa_alarm_settings"),
              let settings = try? JSONDecoder().decode(AlarmSettings.self, from: settingsData) else {
            print("⚠️ BGTaskManager: No alarm settings — skipping reschedule")
            return
        }

        guard settings.alarmsEnabled else {
            print("ℹ️ BGTaskManager: Alarms disabled — skipping reschedule")
            return
        }

        let enabledPrayers = Set(PrayerName.allCases.filter { settings.isEnabled(for: $0) })

        // Reschedule notifications on the main actor (NotificationManager is @MainActor)
        await MainActor.run {
            NotificationManager.shared.schedulePrayerAlarms(
                schedule: todaySchedule,
                tomorrowSchedule: tomorrowSchedule,
                enabledPrayers: enabledPrayers,
                soundName: settings.soundName
            )

            // Also update the keep-alive checker's schedule cache
            BackgroundAudioKeepAlive.shared.updateSchedules(
                today: todaySchedule,
                tomorrow: tomorrowSchedule
            )
        }

        print("✅ BGTaskManager: Rescheduled alarms for \(enabledPrayers.count) prayers at \(location.city)")
    }
}
