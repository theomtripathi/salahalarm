//
//  PrayerTime.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation

/// Represents the five daily prayers plus Imsak
enum PrayerType: String, CaseIterable, Codable {
    case imsak = "Imsak"
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"
    
    var displayName: String {
        return rawValue
    }
    
    var notificationIdentifier: String {
        return "prayer_\(rawValue.lowercased())"
    }
}

/// Represents a prayer time with its date and type
struct PrayerTime: Identifiable, Codable, Hashable {
    let id: UUID
    let type: PrayerType
    let date: Date
    let city: String
    
    init(id: UUID = UUID(), type: PrayerType, date: Date, city: String) {
        self.id = id
        self.type = type
        self.date = date
        self.city = city
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Daily prayer schedule for a specific date
struct DailyPrayerSchedule: Identifiable, Codable {
    let id: UUID
    let date: Date
    let city: String
    let latitude: Double
    let longitude: Double
    let imsak: Date
    let fajr: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date
    let sunrise: Date
    let sunset: Date
    
    init(id: UUID = UUID(), 
         date: Date,
         city: String,
         latitude: Double,
         longitude: Double,
         imsak: Date,
         fajr: Date,
         dhuhr: Date,
         asr: Date,
         maghrib: Date,
         isha: Date,
         sunrise: Date,
         sunset: Date) {
        self.id = id
        self.date = date
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.imsak = imsak
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.sunrise = sunrise
        self.sunset = sunset
    }
    
    var allPrayerTimes: [PrayerTime] {
        [
            PrayerTime(type: .imsak, date: imsak, city: city),
            PrayerTime(type: .fajr, date: fajr, city: city),
            PrayerTime(type: .dhuhr, date: dhuhr, city: city),
            PrayerTime(type: .asr, date: asr, city: city),
            PrayerTime(type: .maghrib, date: maghrib, city: city),
            PrayerTime(type: .isha, date: isha, city: city)
        ]
    }
    
    var currentFastingStatus: FastingStatus {
        let now = Date()
        
        if now < imsak {
            // Before Imsak - not fasting yet
            return .notStarted
        } else if now >= imsak && now < maghrib {
            // Between Imsak and Maghrib - currently fasting
            return .fasting
        } else {
            // After Maghrib - fasting complete for today
            return .completed
        }
    }
    
    var fastingProgress: Double {
        let now = Date()
        let totalDuration = maghrib.timeIntervalSince(imsak)
        let elapsed = now.timeIntervalSince(imsak)
        
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, elapsed / totalDuration))
    }
    
    var timeUntilImsak: TimeInterval? {
        let now = Date()
        if now < imsak {
            return imsak.timeIntervalSince(now)
        }
        return nil
    }
    
    var timeUntilMaghrib: TimeInterval? {
        let now = Date()
        if now < maghrib {
            return maghrib.timeIntervalSince(now)
        }
        return nil
    }
    
    /// Get the next upcoming prayer (name and time)
    /// Returns tomorrow's first prayer if all today's prayers have passed
    /// Note: Imsak is only included during Ramadan
    var nextPrayer: (name: String, time: Date)? {
        let now = Date()
        let calendar = Calendar.current
        let isRamadan = RamadanCalendar.isRamadan(now)
        
        // Build prayers list - include Imsak only during Ramadan
        var prayers: [(String, Date)] = []
        
        if isRamadan {
            prayers.append(("Imsak", imsak))
        }
        
        prayers.append(contentsOf: [
            ("Fajr", fajr),
            ("Dhuhr", dhuhr),
            ("Asr", asr),
            ("Maghrib", maghrib),
            ("Isha", isha)
        ])
        
        // Find the next prayer that hasn't happened yet today
        for (name, prayerTime) in prayers {
            if now < prayerTime {
                return (name, prayerTime)
            }
        }
        
        // All prayers passed today - calculate tomorrow's first prayer
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
            // If tomorrow is also Ramadan, return tomorrow's Imsak, otherwise return tomorrow's Fajr
            if RamadanCalendar.isRamadan(tomorrow) {
                if let tomorrowImsak = calendar.date(bySettingHour: calendar.component(.hour, from: imsak),
                                                    minute: calendar.component(.minute, from: imsak),
                                                    second: 0, of: tomorrow) {
                    return ("Imsak", tomorrowImsak)
                }
            }
            
            // Return tomorrow's Fajr
            if let tomorrowFajr = calendar.date(bySettingHour: calendar.component(.hour, from: fajr),
                                              minute: calendar.component(.minute, from: fajr),
                                              second: 0, of: tomorrow) {
                return ("Fajr", tomorrowFajr)
            }
        }
        
        return nil
    }
}


/// Status of fasting for the current day
enum FastingStatus {
    case notStarted
    case fasting
    case completed
}
