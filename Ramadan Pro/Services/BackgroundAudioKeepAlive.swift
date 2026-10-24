//
//  BackgroundAudioKeepAlive.swift
//  Ramadan Pro
//
//  Keeps the app alive in the background by looping a silent 1-second audio file.
//  When a prayer time is reached, it switches to the real alarm audio and
//  triggers the in-app alarm UI — even before the user taps the notification.
//

import AVFoundation
import Foundation

@MainActor
class BackgroundAudioKeepAlive: NSObject {
    static let shared = BackgroundAudioKeepAlive()

    private var silentPlayer: AVAudioPlayer?
    private var isRunning = false
    private var checkTimer: Timer?

    // Schedule reference — updated by AlarmViewModel whenever prayer times load
    var currentSchedule: DailyPrayerSchedule?
    var tomorrowSchedule: DailyPrayerSchedule?

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Start looping silent audio to keep app alive in background.
    /// Call this when `scenePhase` becomes `.background`.
    func startSilentLoop() {
        guard !isRunning else { return }

        configureAudioSession()

        guard let url = Bundle.main.url(forResource: "silence", withExtension: "caf") else {
            print("⚠️ BackgroundAudioKeepAlive: silence.caf not found in bundle")
            return
        }

        do {
            silentPlayer = try AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1 // loop forever
            silentPlayer?.volume = 0.0       // completely silent
            silentPlayer?.prepareToPlay()
            silentPlayer?.play()
            isRunning = true
            startPrayerTimeChecker()
            print("✅ BackgroundAudioKeepAlive: Silent loop started")
        } catch {
            print("⚠️ BackgroundAudioKeepAlive: Failed to start silent loop — \(error.localizedDescription)")
        }
    }

    /// Stop the silent loop when app returns to foreground.
    /// The in-app timer in HomeView/MainTabView takes over alarm checking.
    func stopSilentLoop() {
        guard isRunning else { return }
        silentPlayer?.stop()
        silentPlayer = nil
        checkTimer?.invalidate()
        checkTimer = nil
        isRunning = false
        print("✅ BackgroundAudioKeepAlive: Silent loop stopped (app is foreground)")
    }

    /// Update prayer schedules so the background checker has fresh data.
    func updateSchedules(today: DailyPrayerSchedule?, tomorrow: DailyPrayerSchedule?) {
        currentSchedule = today
        tomorrowSchedule = tomorrow
    }

    // MARK: - Prayer Time Checker

    /// Fires every 15 seconds while app is in background.
    /// Checks if any enabled prayer time is NOW (within a 60-second window).
    private func startPrayerTimeChecker() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAndTriggerIfPrayerTime()
            }
        }
        // Also add to RunLoop.common so it fires in background
        if let timer = checkTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func checkAndTriggerIfPrayerTime() {
        let now = Date()
        let alarmVM = AlarmViewModel.shared

        // Keep the SalahLock shield in sync while we're alive in the background —
        // this is what flips the lock ON at prayer time even with the app backgrounded.
        AppLockManager.shared.evaluateFromSavedState(now: now)

        guard alarmVM.hasAlarmAccess, alarmVM.settings.alarmsEnabled else { return }

        // Check both today and tomorrow schedules
        for schedule in [currentSchedule, tomorrowSchedule].compactMap({ $0 }) {
            let prayers: [(PrayerName, Date)] = [
                (.fajr,    schedule.fajr),
                (.dhuhr,   schedule.dhuhr),
                (.asr,     schedule.asr),
                (.maghrib, schedule.maghrib),
                (.isha,    schedule.isha)
            ]

            for (prayer, prayerTime) in prayers {
                guard alarmVM.settings.isEnabled(for: prayer) else { continue }

                let secondsUntil = prayerTime.timeIntervalSince(now)
                // Trigger if within 60-second window of prayer time
                if secondsUntil >= -30 && secondsUntil <= 60 {
                    print("🔔 BackgroundAudioKeepAlive: \(prayer.rawValue) time reached, triggering alarm")
                    alarmVM.triggerAlarmFromNotification(prayer: prayer, scheduledTime: prayerTime)
                    return
                }
            }
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback category + mixWithOthers keeps app alive as audio app
            // but doesn't interrupt music etc.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("⚠️ BackgroundAudioKeepAlive: Failed to configure audio session — \(error.localizedDescription)")
        }
    }
}
