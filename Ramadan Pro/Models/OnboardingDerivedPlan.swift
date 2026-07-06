//
//  OnboardingDerivedPlan.swift
//  Ramadan Pro
//

import Foundation

struct OnboardingDerivedPlan: Codable {
    var annualPhoneHours: Int = 0
    var annualPhoneDays: Int = 0
    var lifetimePhoneYears: Int = 0
    var currentHabitSummary: String = ""
    var strengthStatement: String = ""
    var targetConsistencyDate: Date = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
    var commitmentProgressPct: Double = 0
    var primaryGoal: String = ""
    var topGoals: [String] = []
    var alarmCount: Int = 5
    var alarmPrayerNames: [String] = []
    var topObstacles: [String] = []
    var yearlySalahMoments: Int = 1825
}
