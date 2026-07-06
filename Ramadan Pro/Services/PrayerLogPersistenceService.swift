//
//  PrayerLogPersistenceService.swift
//  Ramadan Pro
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct PrayerLogHistoryPayload {
    let today: DailyPrayerLog
    let streak: StreakData
    let weekly: [String: DailyPrayerLog]
}

final class PrayerLogPersistenceService {
    private let db = Firestore.firestore()
    private let firestoreDecoder = Firestore.Decoder()
    private let streakKey = "salahlock_streak_data"
    private let weeklyCacheKey = "salahlock_prayer_weekly_cache"

    private func logKey(for dateString: String) -> String {
        "salahlock_prayer_log_\(dateString)"
    }

    func saveTodayLog(_ log: DailyPrayerLog, dateString: String) async {
        saveLocalLog(log, dateString: dateString)
        await saveLogToFirestore(log, dateString: dateString)
    }

    func saveStreakData(_ streak: StreakData) async {
        if let data = try? JSONEncoder().encode(streak) {
            UserDefaults.standard.set(data, forKey: streakKey)
            WidgetConfig.saveStreakData(streak)
        }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let encoded = try? Firestore.Encoder().encode(streak) else { return }
        try? await db.collection("users").document(userId).setData([
            "streakData": encoded
        ], merge: true)
    }

    func loadHistory() async -> PrayerLogHistoryPayload {
        let todayKey = DateFormatter.yyyyMMdd.string(from: Date())
        let localToday = loadLog(for: todayKey) ?? DailyPrayerLog()
        let localStreak = loadStreakData()
        let localWeekly = loadWeeklyLogs()

        Task {
            await syncFromFirestore()
        }

        return PrayerLogHistoryPayload(today: localToday, streak: localStreak, weekly: localWeekly)
    }

    func loadLog(for dateString: String) -> DailyPrayerLog? {
        guard let data = UserDefaults.standard.data(forKey: logKey(for: dateString)),
              let log = try? JSONDecoder().decode(DailyPrayerLog.self, from: data) else {
            return nil
        }
        return log
    }

    func loadWeeklyLogs(referenceDate: Date = Date()) -> [String: DailyPrayerLog] {
        var result: [String: DailyPrayerLog] = [:]
        for offset in 0..<90 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: referenceDate) else { continue }
            let key = DateFormatter.yyyyMMdd.string(from: day)
            if let log = loadLog(for: key) {
                result[key] = log
            }
        }
        return result
    }

    func loadStreakData() -> StreakData {
        guard let data = UserDefaults.standard.data(forKey: streakKey),
              let streak = try? JSONDecoder().decode(StreakData.self, from: data) else {
            return StreakData()
        }
        return streak
    }

    private func saveLocalLog(_ log: DailyPrayerLog, dateString: String) {
        guard let data = try? JSONEncoder().encode(log) else { return }
        UserDefaults.standard.set(data, forKey: logKey(for: dateString))
        WidgetConfig.savePrayerLog(log, for: dateString)
        UserDefaults.standard.set(Date(), forKey: weeklyCacheKey)
    }

    private func saveLogToFirestore(_ log: DailyPrayerLog, dateString: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let encoded = try? Firestore.Encoder().encode(log) else { return }
        try? await db.collection("users").document(userId).setData([
            "prayerLog": [dateString: encoded]
        ], merge: true)
    }

    private func syncFromFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let snapshot = try? await db.collection("users").document(userId).getDocument(),
              let data = snapshot.data() else { return }

        if let streakMap = data["streakData"] as? [String: Any],
           let streakData = try? decode(streakMap, as: StreakData.self),
           let encoded = try? JSONEncoder().encode(streakData) {
            UserDefaults.standard.set(encoded, forKey: streakKey)
            WidgetConfig.saveStreakData(streakData)
        }

        if let prayerLog = data["prayerLog"] as? [String: [String: Any]] {
            for (dateString, value) in prayerLog {
                if let log = try? decode(value, as: DailyPrayerLog.self) {
                    saveLocalLog(log, dateString: dateString)
                }
            }
        }
    }

    private func decode<T: Decodable>(_ value: [String: Any], as type: T.Type) throws -> T {
        do {
            return try firestoreDecoder.decode(type, from: value)
        } catch {
            let normalized = normalizeFirestoreValue(value)
            let data = try JSONSerialization.data(withJSONObject: normalized, options: [])
            return try JSONDecoder().decode(type, from: data)
        }
    }

    private func normalizeFirestoreValue(_ value: Any) -> Any {
        switch value {
        case let timestamp as Timestamp:
            return ISO8601DateFormatter().string(from: timestamp.dateValue())
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let dictionary as [String: Any]:
            return dictionary.mapValues(normalizeFirestoreValue)
        case let array as [Any]:
            return array.map(normalizeFirestoreValue)
        case is NSNull, is String, is NSNumber, is Bool:
            return value
        default:
            return String(describing: value)
        }
    }
}
