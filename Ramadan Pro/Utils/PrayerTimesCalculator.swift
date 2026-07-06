//
//  PrayerTimesCalculator.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import CoreLocation
import Adhan

/// Prayer times calculation using Adhan-Swift library for accurate calculations
/// This uses battle-tested astronomical algorithms from the Adhan library
class PrayerTimesCalculator {
    
    // Calculation method
    enum CalculationMethod {
        case muslimWorldLeague
        case islamicSocietyOfNorthAmerica
        case egyptianGeneralAuthority
        case ummAlQura
        case gulfRegion
        case kuwait
        case qatar
        case majlisUgamaIslamSingapura
        case turkishDiyanetIsleri
        case custom(fajrAngle: Double, ishaAngle: Double)
    }
    
    // Asr calculation method
    enum AsrMethod {
        case standard
        case hanafi
    }
    
    // Default calculation method
    static let defaultMethod: CalculationMethod = .islamicSocietyOfNorthAmerica
    
    /// Calculate prayer times for a specific date and location using Adhan-Swift
    static func calculatePrayerTimes(
        for date: Date,
        location: UserLocation,
        method: CalculationMethod = defaultMethod,
        asrMethod: AsrMethod = .standard
    ) -> DailyPrayerSchedule {
        
        // Create coordinates
        let coordinates = Coordinates(latitude: location.latitude, longitude: location.longitude)
        
        // Convert to Adhan calculation parameters
        let params = getAdhanCalculationParameters(for: method, asrMethod: asrMethod)
        
        // Get calendar for date manipulation - Adhan expects DateComponents
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        // Calculate prayer times using Adhan - result is optional
        guard let prayers = PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params) else {
            // Fallback: create a basic schedule if calculation fails
            let now = Date()
            let fallbackDate = calendar.date(from: dateComponents) ?? now
            return DailyPrayerSchedule(
                date: date,
                city: location.city,
            latitude: location.latitude,
            longitude: location.longitude,
                imsak: fallbackDate,
                fajr: fallbackDate,
                dhuhr: fallbackDate,
                asr: fallbackDate,
                maghrib: fallbackDate,
                isha: fallbackDate,
                sunrise: fallbackDate,
                sunset: fallbackDate
            )
        }
        
        // Imsak is typically 10 minutes before Fajr
        let imsak = prayers.fajr.addingTimeInterval(-10 * 60)
        
        return DailyPrayerSchedule(
            date: date,
            city: location.city,
            latitude: location.latitude,
            longitude: location.longitude,
            imsak: imsak,
            fajr: prayers.fajr,
            dhuhr: prayers.dhuhr,
            asr: prayers.asr,
            maghrib: prayers.maghrib,
            isha: prayers.isha,
            sunrise: prayers.sunrise,
            sunset: prayers.maghrib // Sunset is same as Maghrib
        )
    }
    
    // MARK: - Private Calculation Methods
    
    /// Convert our CalculationMethod to Adhan's CalculationParameters
    private static func getAdhanCalculationParameters(for method: CalculationMethod, asrMethod: AsrMethod) -> CalculationParameters {
        let madhab: Madhab = asrMethod == .hanafi ? .hanafi : .shafi
        
        // Adhan's CalculationMethod enum has a .params property that returns CalculationParameters
        var params: CalculationParameters
        
        switch method {
        case .muslimWorldLeague:
            params = Adhan.CalculationMethod.muslimWorldLeague.params
        case .egyptianGeneralAuthority:
            params = Adhan.CalculationMethod.egyptian.params
        case .ummAlQura:
            params = Adhan.CalculationMethod.ummAlQura.params
        case .gulfRegion:
            // Gulf region - using Dubai method (UAE is in the Gulf region)
            params = Adhan.CalculationMethod.dubai.params
        case .kuwait:
            params = Adhan.CalculationMethod.kuwait.params
        case .qatar:
            params = Adhan.CalculationMethod.qatar.params
        case .majlisUgamaIslamSingapura:
            params = Adhan.CalculationMethod.singapore.params
        case .turkishDiyanetIsleri:
            params = Adhan.CalculationMethod.turkey.params
        case .islamicSocietyOfNorthAmerica:
            // ISNA is mapped to northAmerica in Adhan
            params = Adhan.CalculationMethod.northAmerica.params
        case .custom(let fajrAngle, let ishaAngle):
            // Custom angles - use other method and override angles
            params = Adhan.CalculationMethod.other.params
            params.fajrAngle = fajrAngle
            params.ishaAngle = ishaAngle
        }
        
        params.madhab = madhab
        return params
    }
    
    // Keep this for backwards compatibility if needed elsewhere
    private static func getCalculationParameters(for method: CalculationMethod) -> (fajrAngle: Double, ishaAngle: Double) {
        switch method {
        case .muslimWorldLeague:
            return (18.0, 17.0)
        case .islamicSocietyOfNorthAmerica:
            return (15.0, 15.0)
        case .egyptianGeneralAuthority:
            return (19.5, 17.5)
        case .ummAlQura:
            return (18.5, 90.0) // Special case for Umm Al-Qura
        case .gulfRegion:
            return (19.5, 90.0)
        case .kuwait:
            return (18.0, 17.5)
        case .qatar:
            return (18.0, 90.0)
        case .majlisUgamaIslamSingapura:
            return (20.0, 18.0)
        case .turkishDiyanetIsleri:
            return (18.0, 17.0)
        case .custom(let fajrAngle, let ishaAngle):
            return (fajrAngle, ishaAngle)
        }
    }
    
}

// MARK: - Math Extensions

extension Double {
    var radians: Double {
        return self * .pi / 180.0
    }
    
    var degrees: Double {
        return self * 180.0 / .pi
    }
}
