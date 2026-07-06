//
//  RamadanDay.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation

/// Helper to calculate Ramadan dates
struct RamadanCalendar {
    /// Calculate Ramadan start and end dates for a given year
    /// Note: This is a simplified calculation. In production, you should use astronomical calculations
    /// or an Islamic calendar library for accurate dates based on moon sighting
    static func ramadanDates(for year: Int) -> (start: Date, end: Date)? {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = 3 // March (approximately)
        components.day = 11 // Approximate start - adjust based on lunar calendar
        
        guard let startDate = calendar.date(from: components) else { return nil }
        
        // Ramadan is approximately 29-30 days
        guard let endDate = calendar.date(byAdding: .day, value: 30, to: startDate) else { return nil }
        
        return (start: startDate, end: endDate)
    }
    
    /// Check if a given date falls within Ramadan
    static func isRamadan(_ date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        
        guard let (start, end) = ramadanDates(for: year) else { return false }
        
        return date >= start && date <= end
    }
    
    /// Get the day number of Ramadan for a given date
    static func dayNumber(for date: Date = Date()) -> Int? {
        guard isRamadan(date) else { return nil }
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        
        guard let (start, _) = ramadanDates(for: year) else { return nil }
        
        let days = calendar.dateComponents([.day], from: start, to: date).day ?? 0
        return days + 1
    }
}
