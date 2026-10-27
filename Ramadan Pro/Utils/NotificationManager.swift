//
//  NotificationManager.swift
//  Ramadan Pro
//

import Foundation
import UserNotifications

/// Manages prayer time notifications and alarm scheduling
@MainActor
class NotificationManager {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()

    // Notification category/action identifiers
    static let alarmCategoryID     = "PRAYER_ALARM"
    static let dismissActionID     = "DISMISS_ALARM"
    static let snoozeActionID      = "SNOOZE_ALARM"
    static let alarmNotifPrefix    = "prayer_alarm_"

    private init() {
        registerNotificationCategories()
    }

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge, .criticalAlert]
            )
            DebugLogger.log("Notification authorization: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            // criticalAlert may be denied — retry without it
            do {
                let granted = try await notificationCenter.requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
                return granted
            } catch {
                DebugLogger.logError("Notification auth failed: \(error.localizedDescription)")
                return false
            }
        }
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Register Categories

    private func registerNotificationCategories() {
        let dismissAction = UNNotificationAction(
            identifier: Self.dismissActionID,
            title: "Dismiss",
            options: [.destructive, .authenticationRequired]
        )
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "Snooze 5 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.alarmCategoryID,
            actions: [dismissAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        notificationCenter.setNotificationCategories([category])
    }

    // MARK: - Schedule Alarm Notifications

    /// Schedule alarm notifications for every enabled prayer.
    /// Call this whenever settings change or a new schedule is loaded.
    func schedulePrayerAlarms(
        schedule: DailyPrayerSchedule,
        tomorrowSchedule: DailyPrayerSchedule?,
        enabledPrayers: Set<PrayerName>,
        soundName: String
    ) {
        // Remove old alarm notifications first
        cancelAllAlarmNotifications()

        guard !enabledPrayers.isEmpty else { return }

        let sound = resolvedNotificationSound(for: soundName)

        // Schedule today + tomorrow
        for s in [schedule, tomorrowSchedule].compactMap({ $0 }) {
            scheduleDayAlarms(schedule: s, enabled: enabledPrayers, sound: sound)
        }

        DebugLogger.logSuccess("Prayer alarm notifications scheduled for \(enabledPrayers.count) prayers")
    }

    private func scheduleDayAlarms(
        schedule: DailyPrayerSchedule,
        enabled: Set<PrayerName>,
        sound: UNNotificationSound
    ) {
        let prayers: [(PrayerName, Date)] = [
            (.fajr,    schedule.fajr),
            (.dhuhr,   schedule.dhuhr),
            (.asr,     schedule.asr),
            (.maghrib, schedule.maghrib),
            (.isha,    schedule.isha)
        ]

        let now = Date()
        for (prayer, time) in prayers where enabled.contains(prayer) {
            guard time > now else { continue }
            scheduleAlarmNotification(prayer: prayer, at: time, sound: sound)
        }
    }

    private func scheduleAlarmNotification(prayer: PrayerName, at time: Date, sound: UNNotificationSound) {
        let content = UNMutableNotificationContent()
        content.title = "🕌 \(prayer.displayName) Prayer"
        content.body  = "It's time for \(prayer.displayName). Tap to confirm."
        content.sound = sound
        content.badge = 1
        content.categoryIdentifier = Self.alarmCategoryID
        content.userInfo = [
            "prayerType": prayer.rawValue,
            "prayerTime": time.timeIntervalSince1970,
            "isAlarm": true
        ]
        // Interrupt level — raise alarm above silent switch when possible
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let id = "\(Self.alarmNotifPrefix)\(prayer.rawValue)_\(Int(time.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error {
                DebugLogger.logError("Failed scheduling \(prayer.rawValue) alarm: \(error.localizedDescription)")
            } else {
                DebugLogger.log("Scheduled \(prayer.rawValue) alarm at \(time)")
            }
        }
    }

    // MARK: - Sound Resolution

    private func resolvedNotificationSound(for soundName: String) -> UNNotificationSound {
        if let option = AlarmSoundOption(rawValue: soundName), option != .custom {
            // Use the trimmed ≤29s CAF file so iOS plays it at full volume from the notification
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: option.notifSoundFileName))
        }
        // Custom or unknown: fall back to default critical sound
        return UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
    }

    // MARK: - Cancel

    func cancelAllAlarmNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(Self.alarmNotifPrefix) }
                .map(\.identifier)
            if !ids.isEmpty {
                self.notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
                DebugLogger.log("Cancelled \(ids.count) alarm notifications")
            }
        }
    }

    func cancelAllPrayerNotifications() {
        cancelAllAlarmNotifications()
    }

    // MARK: - Legacy Imsak / Iftar reminders (keep for Ramadan tab)

    func scheduleNotifications(for schedule: DailyPrayerSchedule, cancelExisting: Bool = false) {
        if cancelExisting { cancelAllPrayerNotifications() }

        let prayers: [(String, Date, PrayerType)] = [
            ("Imsak",  schedule.imsak,   .imsak),
            ("Iftar",  schedule.maghrib, .maghrib)
        ]
        for (name, time, type) in prayers {
            scheduleReminderNotification(for: type, prayerName: name, prayerTime: time, minutesBefore: 30)
            scheduleReminderNotification(for: type, prayerName: name, prayerTime: time, minutesBefore: 1)
        }
    }

    func scheduleNotificationsForUpcomingDays(
        currentSchedule: DailyPrayerSchedule,
        tomorrowSchedule: DailyPrayerSchedule?,
        location: UserLocation
    ) {
        cancelAllPrayerNotifications()
        scheduleNotifications(for: currentSchedule, cancelExisting: false)
        if let tomorrow = tomorrowSchedule {
            scheduleNotifications(for: tomorrow, cancelExisting: false)
        }
    }

    private func scheduleReminderNotification(
        for prayerType: PrayerType,
        prayerName: String,
        prayerTime: Date,
        minutesBefore: Int
    ) {
        let notificationDate = prayerTime.addingTimeInterval(-Double(minutesBefore) * 60)
        guard notificationDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(prayerName) Reminder"
        content.body  = "\(prayerName) is in \(minutesBefore) minute\(minutesBefore == 1 ? "" : "s")"
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "prayerType": prayerType.rawValue,
            "prayerName": prayerName,
            "prayerTime": prayerTime.timeIntervalSince1970
        ]

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = "\(prayerType.notificationIdentifier)_\(minutesBefore)min"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error {
                DebugLogger.logError("Failed scheduling reminder for \(prayerName): \(error.localizedDescription)")
            }
        }
    }

    func scheduleFiveDailyPrayerReminders(times: [PrayerTime]) {
        cancelAllPrayerNotifications()

        for prayer in times where prayer.type != .imsak {
            let content = UNMutableNotificationContent()
            content.title = "SalahAlarm"
            content.body  = "🕌 It's time for \(prayer.type.displayName). Open SalahAlarm and stay on track."
            content.sound = .default
            content.userInfo = [
                "prayerType": prayer.type.rawValue,
                "prayerTime": prayer.date.timeIntervalSince1970
            ]

            let components = Calendar.current.dateComponents([.hour, .minute], from: prayer.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = "prayer_daily_\(prayer.type.rawValue.lowercased())"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            notificationCenter.add(request) { error in
                if let error {
                    DebugLogger.logError("Failed scheduling daily reminder \(prayer.type.rawValue): \(error.localizedDescription)")
                }
            }
        }
    }
}
