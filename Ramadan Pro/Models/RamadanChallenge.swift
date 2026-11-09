//
//  RamadanChallenge.swift
//  Ramadan Pro
//
//  The 90-Day Ramadan Ready challenge (#ImRamadanReady): one shared cohort
//  from 10 Nov 2026 to 7 Feb 2027, the night before Ramadan 1448 is expected
//  to begin. Progress is derived from the existing daily prayer log.
//

import Foundation

enum RamadanChallenge {
    static let lengthInDays = 90
    static let phaseLength = 30
    static let graceDaysPerPhase = 3
    static let hashtag = "#ImRamadanReady"
    static let inviteBaseURL = "https://salahalarm.com/c/"
    static let landingURL = URL(string: "https://salahalarm.com/ramadan-2027")!
    static let rulesURL = URL(string: "https://salahalarm.com/ramadan-2027/rules")!

    /// Day 1 of the challenge.
    static var startDate: Date { makeDate(2026, 11, 10) }
    /// Last day to join (a 30-day track still fits before Ramadan).
    static var prizeJoinCutoff: Date { makeDate(2027, 1, 9) }
    /// Free Makkah Trip prize draw (Umrah trip for 2).
    static var drawDate: Date { makeDate(2027, 2, 10) }
    /// Cap on draw entries earned from invited friends.
    static let maxReferralEntries = 50

    /// Draw entries for full days: 30 = 1, 60 = 2, 90 = 3.
    static func dayEntries(completedDays: Int) -> Int {
        min(3, completedDays / 30)
    }

    /// Total entries. Friend entries only count once the user has an entry
    /// of their own; the server confirms friend full days before the draw.
    static func totalEntries(completedDays: Int, qualifiedFriends: Int) -> Int {
        let own = dayEntries(completedDays: completedDays)
        guard own > 0 else { return 0 }
        return own + min(max(0, qualifiedFriends), maxReferralEntries)
    }
    /// Expected first day of Ramadan 1448 (depends on the moon sighting).
    static var expectedRamadanStart: Date { makeDate(2027, 2, 8) }

    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private static func daysBetween(_ from: Date, _ to: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    /// 1-based challenge day. 0 or less before Day 1, above 90 after the end.
    static func dayNumber(on date: Date = Date()) -> Int {
        daysBetween(startDate, date) + 1
    }

    static func daysUntilStart(from date: Date = Date()) -> Int {
        max(0, daysBetween(date, startDate))
    }

    static func daysUntilRamadan(from date: Date = Date()) -> Int {
        max(0, daysBetween(date, expectedRamadanStart))
    }

    static func phase(forDay day: Int) -> Int {
        min(3, max(1, (day - 1) / phaseLength + 1))
    }

    static func phaseTitle(_ phase: Int) -> String {
        switch phase {
        case 1: return L10n.text("Phase 1: Fajr foundation")
        case 2: return L10n.text("Phase 2: Five a day")
        default: return L10n.text("Phase 3: Sha'ban training")
        }
    }

    static func inviteURL(for code: String) -> URL? {
        URL(string: inviteBaseURL + code)
    }
}

struct ChallengeEnrollment: Codable, Equatable {
    var joinedAt: Date
    /// This user's own invite code.
    var code: String
    /// The code of the friend who invited them, if any.
    var invitedBy: String?
}

enum ChallengeTier: Equatable {
    case none
    case bronze        // 30 days done
    case silver        // 80% of days done
    case ramadanReady  // all 90 days, within the grace days

    var title: String {
        switch self {
        case .none: return L10n.text("Getting started")
        case .bronze: return L10n.text("Bronze")
        case .silver: return L10n.text("Silver")
        case .ramadanReady: return L10n.text("Ramadan Ready")
        }
    }
}

struct ChallengeProgress: Equatable {
    /// Current challenge day, clamped to 0...90 (0 = not started yet).
    let day: Int
    let completedDays: Int
    let missedDays: Int
    let phase: Int
    let graceLeftThisPhase: Int
    let isOnTrack: Bool
    let todayComplete: Bool

    var tier: ChallengeTier {
        if day >= RamadanChallenge.lengthInDays && isOnTrack { return .ramadanReady }
        let counted = completedDays + missedDays
        if counted >= 30 && Double(completedDays) >= Double(counted) * 0.8 { return .silver }
        if completedDays >= 30 { return .bronze }
        return .none
    }

    /// A day counts when all five prayers were confirmed. Days before the
    /// user joined are not counted against them (late joiners run a shorter track).
    static func compute(
        enrollment: ChallengeEnrollment,
        logs: [String: DailyPrayerLog],
        now: Date = Date()
    ) -> ChallengeProgress {
        let calendar = Calendar.current
        let today = RamadanChallenge.dayNumber(on: now)
        let clampedToday = min(max(today, 0), RamadanChallenge.lengthInDays)
        guard clampedToday >= 1 else {
            return ChallengeProgress(day: 0, completedDays: 0, missedDays: 0, phase: 1,
                                     graceLeftThisPhase: RamadanChallenge.graceDaysPerPhase,
                                     isOnTrack: true, todayComplete: false)
        }

        let firstCountedDay = max(1, RamadanChallenge.dayNumber(on: enrollment.joinedAt))
        var completed = 0
        var missed = 0
        var missedByPhase = [1: 0, 2: 0, 3: 0]
        var todayComplete = false

        if firstCountedDay <= clampedToday {
            for dayNumber in firstCountedDay...clampedToday {
                guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: RamadanChallenge.startDate) else { continue }
                let done = logs[DateFormatter.yyyyMMdd.string(from: date)]?.allFivePrayed ?? false
                let isToday = dayNumber == today
                if done {
                    completed += 1
                    if isToday { todayComplete = true }
                } else if !isToday {
                    // Today is still in progress, so it isn't a miss yet.
                    missed += 1
                    missedByPhase[RamadanChallenge.phase(forDay: dayNumber), default: 0] += 1
                }
            }
        }

        let phase = RamadanChallenge.phase(forDay: clampedToday)
        let onTrack = missedByPhase.values.allSatisfy { $0 <= RamadanChallenge.graceDaysPerPhase }
        let graceLeft = max(0, RamadanChallenge.graceDaysPerPhase - (missedByPhase[phase] ?? 0))

        return ChallengeProgress(day: clampedToday, completedDays: completed, missedDays: missed,
                                 phase: phase, graceLeftThisPhase: graceLeft,
                                 isOnTrack: onTrack, todayComplete: todayComplete)
    }
}
