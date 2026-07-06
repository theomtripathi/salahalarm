//
//  PrayerLog.swift
//  Ramadan Pro
//

import Foundation

enum PrayerName: String, CaseIterable, Codable, Hashable, Identifiable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Mghrb"
        case .isha: return "Isha"
        }
    }

    var emoji: String {
        switch self {
        case .fajr: return "🌅"
        case .dhuhr: return "☀️"
        case .asr: return "🌤"
        case .maghrib: return "🌇"
        case .isha: return "🌙"
        }
    }

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }
}

struct DailyPrayerLog: Codable, Hashable {
    var fajr: Bool = false
    var dhuhr: Bool = false
    var asr: Bool = false
    var maghrib: Bool = false
    var isha: Bool = false
    var confirmedAt: [Date] = []

    var allFivePrayed: Bool { fajr && dhuhr && asr && maghrib && isha }
    var prayedCount: Int { [fajr, dhuhr, asr, maghrib, isha].filter { $0 }.count }

    func isConfirmed(_ prayer: PrayerName) -> Bool {
        switch prayer {
        case .fajr: return fajr
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }
}

struct StreakData: Codable, Hashable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastStreakDate: String = ""
    var totalPrayerDays: Int = 0
    var totalPrayersConfirmed: Int = 0
}
