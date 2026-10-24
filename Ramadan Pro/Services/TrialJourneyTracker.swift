import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Tracks a small set of first-win milestones for a verified RevenueCat trial.
/// Customer identifiers are used only in local UserDefaults keys and never sent.
@MainActor
final class TrialJourneyTracker {
#if canImport(RevenueCat)
    static let shared = TrialJourneyTracker(
        defaults: .standard,
        customerIDProvider: { Purchases.shared.appUserID },
        eventRecorder: { FunnelAnalytics.shared.track($0, $1) }
    )
#else
    static let shared = TrialJourneyTracker(
        defaults: .standard,
        customerIDProvider: { "test" },
        eventRecorder: { _, _ in }
    )
#endif

    private let defaults: UserDefaults
    private let customerIDProvider: () -> String
    private let eventRecorder: (FunnelEvent, [String: Any]) -> Void
    // Trial-day deduplication uses Gregorian calendar days in UTC, independent of device locale.
    private let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    init(
        defaults: UserDefaults = .standard,
        customerIDProvider: @escaping () -> String,
        eventRecorder: @escaping (FunnelEvent, [String: Any]) -> Void
    ) {
        self.defaults = defaults
        self.customerIDProvider = customerIDProvider
        self.eventRecorder = eventRecorder
    }

    func recordView(status: SubscriptionStatus, now: Date = Date()) {
        guard let journey = verifiedJourney(status: status, now: now) else { return }
        let day = utcDay(for: now)
        let key = journeyKey(journey, suffix: "view_\(day)")
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        eventRecorder(.trialJourneyViewed, ["trial_day": dayOffset(from: journey.start, to: now)])
    }

    func recordAlarmConfigured(status: SubscriptionStatus, settings: AlarmSettings, now: Date = Date()) {
        guard settings.alarmsEnabled,
              PrayerName.allCases.contains(where: { settings.isEnabled(for: $0) }),
              let journey = verifiedJourney(status: status, now: now) else { return }
        recordMilestone("alarm_configured", journey: journey, now: now)
        recordMeaningfulReturn(status: status, now: now)
    }

    func recordPrayerConfirmation(status: SubscriptionStatus, confirmedAt: Date, now: Date = Date()) {
        guard let journey = verifiedJourney(status: status, now: now),
              confirmedAt >= journey.start,
              confirmedAt <= now,
              confirmedAt <= journey.end else { return }
        recordMilestone("first_prayer_logged", journey: journey, now: now)
    }

    func recordMeaningfulReturn(status: SubscriptionStatus, now: Date = Date()) {
        guard let journey = verifiedJourney(status: status, now: now),
              utcDay(for: now) > utcDay(for: journey.start) else { return }
        recordMilestone("meaningful_return_day", journey: journey, now: now, deduplicationDay: utcDay(for: now))
    }

    private func verifiedJourney(status: SubscriptionStatus, now: Date) -> (start: Date, end: Date, identity: String)? {
        guard status.isActive, status.isInTrial,
              let start = status.startDate,
              let end = status.trialEndDate ?? status.expiryDate,
              start <= now, end > now, end > start else { return nil }
        // The customer identity stays local: it scopes deduplication and is never sent.
        let identity = customerIDProvider()
        return (start, end, "\(identity)|\(Int(start.timeIntervalSince1970))|\(Int(end.timeIntervalSince1970))")
    }

    private func recordMilestone(
        _ milestone: String,
        journey: (start: Date, end: Date, identity: String),
        now: Date,
        deduplicationDay: Int? = nil
    ) {
        let suffix = deduplicationDay.map { "\(milestone)_utcday_\($0)" } ?? milestone
        let key = journeyKey(journey, suffix: suffix)
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        eventRecorder(.trialJourneyAction, [
            "milestone": milestone,
            "trial_day": dayOffset(from: journey.start, to: now)
        ])
    }

    private func journeyKey(_ journey: (start: Date, end: Date, identity: String), suffix: String) -> String {
        "trial_journey_v1_\(journey.identity)_\(suffix)"
    }

    private func utcDay(for date: Date) -> Int {
        utcCalendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    private func dayOffset(from start: Date, to date: Date) -> Int {
        let startDay = utcCalendar.startOfDay(for: start)
        let currentDay = utcCalendar.startOfDay(for: date)
        return max(0, utcCalendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0)
    }
}
