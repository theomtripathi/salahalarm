//
//  PrayerLogViewModel.swift
//  Ramadan Pro
//

import Foundation
import Combine

@MainActor
final class PrayerLogViewModel: ObservableObject {
    static let shared = PrayerLogViewModel()

    @Published var todayLog: DailyPrayerLog = DailyPrayerLog()
    @Published var streakData: StreakData = StreakData()
    @Published var weeklyLogs: [String: DailyPrayerLog] = [:]
    @Published var isLoading: Bool = false

    private let persistence = PrayerLogPersistenceService()

    private init() {}

    func load() async {
        isLoading = true
        let payload = await persistence.loadHistory()
        todayLog = payload.today
        streakData = payload.streak
        weeklyLogs = payload.weekly
        WidgetConfig.savePrayerLog(todayLog, for: DateFormatter.yyyyMMdd.string(from: Date()))
        isLoading = false
    }

    func confirmPrayer(_ prayer: PrayerName) async {
        var log = todayLog
        if log.isConfirmed(prayer) {
            return
        }

        switch prayer {
        case .fajr: log.fajr = true
        case .dhuhr: log.dhuhr = true
        case .asr: log.asr = true
        case .maghrib: log.maghrib = true
        case .isha: log.isha = true
        }
        log.confirmedAt.append(Date())
        todayLog = log
        let todayKey = DateFormatter.yyyyMMdd.string(from: Date())
        weeklyLogs[todayKey] = log

        var updatedStreak = streakData
        updatedStreak.totalPrayersConfirmed += 1
        if log.allFivePrayed && updatedStreak.lastStreakDate != todayKey {
            let yesterday = DateFormatter.yyyyMMdd.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            if updatedStreak.lastStreakDate == yesterday {
                updatedStreak.currentStreak += 1
            } else {
                updatedStreak.currentStreak = 1
            }
            updatedStreak.longestStreak = max(updatedStreak.longestStreak, updatedStreak.currentStreak)
            updatedStreak.lastStreakDate = todayKey
            updatedStreak.totalPrayerDays += 1
        }
        streakData = updatedStreak

        await persistence.saveTodayLog(log, dateString: todayKey)
        await persistence.saveStreakData(updatedStreak)
        if let confirmedAt = log.confirmedAt.last {
            TrialJourneyTracker.shared.recordPrayerConfirmation(
                status: RevenueCatService.shared.subscriptionStatus,
                confirmedAt: confirmedAt
            )
            TrialJourneyTracker.shared.recordMeaningfulReturn(status: RevenueCatService.shared.subscriptionStatus)
        }
        WidgetHelper.reloadAllWidgets()
        // Confirming a prayer is what unlocks the SalahLock shield
        AppLockManager.shared.refreshLog(log)
    }

    func log(for date: Date) -> DailyPrayerLog {
        weeklyLogs[DateFormatter.yyyyMMdd.string(from: date)] ?? DailyPrayerLog()
    }

    var todayConfirmedCount: Int {
        todayLog.prayedCount
    }
}
