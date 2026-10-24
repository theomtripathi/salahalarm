//
//  NotificationDelegate.swift
//  Ramadan Pro
//

import Foundation
import UserNotifications
import UIKit

/// Handles notification interactions and wakes the in-app alarm on tap
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    override private init() {
        super.init()
    }

    // MARK: - Foreground presentation

    /// When the app is in the foreground and a prayer alarm fires,
    /// show the banner + play sound, then immediately trigger the in-app alarm.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        if userInfo["isAlarm"] as? Bool == true {
            // Trigger the in-app alarm screen right away (app is open)
            triggerInAppAlarm(from: userInfo)
            // Prayer time just arrived — engage the SalahLock shield
            Task { @MainActor in
                AppLockManager.shared.evaluateFromSavedState()
            }
            // Still play the banner sound so the user notices if they're on another screen
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }

    // MARK: - Notification tap

    /// Called when user taps the notification (app was in background/killed).
    /// We open the app and immediately show the looping alarm screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if userInfo["isAlarm"] as? Bool == true {
            // Give the app a moment to fully launch before posting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.triggerInAppAlarm(from: userInfo)
            }
            // App just launched from the prayer notification — sync the lock
            Task { @MainActor in
                AppLockManager.shared.evaluateFromSavedState()
            }
        } else {
            // Legacy reminder tap — navigate to prayer tab
            if let prayerType = userInfo["prayerType"] as? String {
                DebugLogger.log("Reminder tapped for prayer: \(prayerType)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToPrayer"),
                    object: nil,
                    userInfo: ["prayerType": prayerType]
                )
            }
        }

        completionHandler()
    }

    // MARK: - Private

    private func triggerInAppAlarm(from userInfo: [AnyHashable: Any]) {
        guard let prayerRaw = userInfo["prayerType"] as? String,
              let prayer = PrayerName(rawValue: prayerRaw) else { return }

        let scheduledTime: Date
        if let ts = userInfo["prayerTime"] as? TimeInterval {
            scheduledTime = Date(timeIntervalSince1970: ts)
        } else {
            scheduledTime = Date()
        }

        DebugLogger.log("🔔 NotificationDelegate: Triggering in-app alarm for \(prayer.rawValue)")

        // Post to AlarmViewModel on main thread
        Task { @MainActor in
            AlarmViewModel.shared.triggerAlarmFromNotification(prayer: prayer, scheduledTime: scheduledTime)
        }
    }
}
