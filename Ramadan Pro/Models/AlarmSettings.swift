//
//  AlarmSettings.swift
//  Ramadan Pro
//

import Foundation

enum AlarmSoundOption: String, Codable, CaseIterable {
    case makkahLoud = "Makkah Adhan Loud"
    case madinahLoud = "Madinah Adhan Loud"
    case fajrLoud = "Fajr Adhan Loud"
    case takbirLoud = "Takbir Alarm Loud"
    case newAudio = "Funny Wake Up Bitch"
    case custom = "Custom Audio"

    var description: String {
        switch self {
        case .makkahLoud:
            return "A full, loud adhan-style call tuned for daily prayers."
        case .madinahLoud:
            return "A strong, clear mosque-style adhan with a steady tone."
        case .fajrLoud:
            return "A more piercing wake-up style option for early mornings."
        case .takbirLoud:
            return "A high-intensity alarm fallback when you need something sharp."
        case .newAudio:
            return "A funny wake-up alarm sound."
        case .custom:
            return "Select a custom audio file from your device."
        }
    }

    var shortLabel: String {
        switch self {
        case .makkahLoud:
            return "Makkah"
        case .madinahLoud:
            return "Madinah"
        case .fajrLoud:
            return "Fajr"
        case .takbirLoud:
            return "Takbir"
        case .newAudio:
            return "Funny Wake Up Bitch"
        case .custom:
            return "Custom"
        }
    }

    var assetFileName: String {
        switch self {
        case .makkahLoud:  return "alarm_makkah_loud"
        case .madinahLoud: return "alarm_madinah_loud"
        case .fajrLoud:    return "alarm_fajr_loud"
        case .takbirLoud:  return "alarm_takbir_loud"
        case .newAudio:    return "wake-up"
        case .custom:      return "custom"
        }
    }

    /// The ≤29s .caf file used for UNNotificationSound (iOS only plays bundle sounds ≤30s)
    var notifSoundFileName: String {
        switch self {
        case .makkahLoud:  return "alarm_makkah_loud_notif.caf"
        case .madinahLoud: return "alarm_madinah_loud_notif.caf"
        case .fajrLoud:    return "alarm_fajr_loud_notif.caf"
        case .takbirLoud:  return "alarm_takbir_loud_notif.caf"
        case .newAudio:    return "wake-up_notif.caf"
        case .custom:      return "alarm_fajr_loud_notif.caf" // fallback for custom
        }
    }
}

enum AlarmStrictness: String, Codable, CaseIterable {
    case strict
    case moderate
    case relaxed

    var displayLabel: String {
        switch self {
        case .strict:
            return "Strict"
        case .moderate:
            return "Moderate"
        case .relaxed:
            return "Relaxed"
        }
    }

    var onboardingLabel: String {
        switch self {
        case .strict:
            return "Strict - rings until I scan my mat"
        case .moderate:
            return "Moderate - 10 minutes, then marks missed"
        case .relaxed:
            return "Relaxed - one snooze, then must scan"
        }
    }

    var detailText: String {
        switch self {
        case .strict:
            return "Rings until you dismiss it from the prayer flow."
        case .moderate:
            return "Lets the alarm expire after 10 minutes if you miss it."
        case .relaxed:
            return "Allows one snooze before asking you to dismiss it."
        }
    }
}

struct AlarmSettings: Codable {
    var fajrEnabled: Bool = true
    var dhuhrEnabled: Bool = true
    var asrEnabled: Bool = true
    var maghribEnabled: Bool = true
    var ishaEnabled: Bool = true
    var strictness: AlarmStrictness = .strict
    var soundName: String = AlarmSoundOption.makkahLoud.rawValue
    var volume: Float = 1.0
    var vibrationEnabled: Bool = true
    var alarmsEnabled: Bool = true
    var matSetupCompleted: Bool = false

    func isEnabled(for prayer: PrayerName) -> Bool {
        switch prayer {
        case .fajr: return fajrEnabled
        case .dhuhr: return dhuhrEnabled
        case .asr: return asrEnabled
        case .maghrib: return maghribEnabled
        case .isha: return ishaEnabled
        }
    }

    mutating func setEnabled(_ isEnabled: Bool, for prayer: PrayerName) {
        switch prayer {
        case .fajr: fajrEnabled = isEnabled
        case .dhuhr: dhuhrEnabled = isEnabled
        case .asr: asrEnabled = isEnabled
        case .maghrib: maghribEnabled = isEnabled
        case .isha: ishaEnabled = isEnabled
        }
    }
}
