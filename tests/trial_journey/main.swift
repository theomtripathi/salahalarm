import Foundation

enum FunnelEvent: String {
    case trialJourneyViewed
    case trialJourneyAction
}

struct SubscriptionStatus {
    let isActive: Bool
    let isInTrial: Bool
    let startDate: Date?
    let expiryDate: Date?
    let trialEndDate: Date?

    var isExpired: Bool {
        guard let expiryDate else { return !isActive }
        return Date() > expiryDate
    }
}

enum PrayerName: CaseIterable { case fajr }

struct AlarmSettings {
    let alarmsEnabled: Bool
    func isEnabled(for prayer: PrayerName) -> Bool { true }
}

@MainActor
@main
struct TrialJourneyTests {
    static func main() {
        var events: [(FunnelEvent, [String: Any])] = []
        let suite = "TrialJourneyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let tracker = TrialJourneyTracker(
            defaults: defaults,
            customerIDProvider: { "local-customer" },
            eventRecorder: { events.append(($0, $1)) }
        )

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = utc.date(from: DateComponents(year: 2020, month: 1, day: 1, hour: 23, minute: 59))!
        let dayOne = start.addingTimeInterval(120)
        let dayTwo = utc.date(from: DateComponents(year: 2020, month: 1, day: 3, hour: 1))!
        let end = utc.date(from: DateComponents(year: 2020, month: 1, day: 8))!
        let status = SubscriptionStatus(isActive: true, isInTrial: true, startDate: start, expiryDate: end, trialEndDate: end)

        check(status.isExpired, "fixture is expired relative to wall clock to catch accidental Date()-based gating")
        tracker.recordView(status: status, now: start)
        tracker.recordView(status: status, now: start)
        check(events.count == 1 && trialDay(events[0]) == 0, "view is deduped on D0 and trial_day is zero-based")

        tracker.recordView(status: status, now: dayOne)
        check(events.count == 2 && trialDay(events[1]) == 1, "UTC midnight advances to D1 even within 24 hours")

        tracker.recordMeaningfulReturn(status: status, now: start)
        tracker.recordMeaningfulReturn(status: status, now: dayOne)
        tracker.recordMeaningfulReturn(status: status, now: dayOne)
        tracker.recordMeaningfulReturn(status: status, now: dayTwo)
        let returns = events.filter { action($0) == "meaningful_return_day" }
        check(returns.count == 2, "meaningful return is action-triggered and deduped once per UTC day")

        tracker.recordPrayerConfirmation(status: status, confirmedAt: start.addingTimeInterval(-1), now: dayOne)
        tracker.recordPrayerConfirmation(status: status, confirmedAt: dayTwo, now: dayOne)
        check(events.filter { action($0) == "first_prayer_logged" }.isEmpty, "future or pre-trial confirmations never count")
        tracker.recordPrayerConfirmation(status: status, confirmedAt: dayOne, now: dayOne)
        tracker.recordPrayerConfirmation(status: status, confirmedAt: dayOne, now: dayOne)
        check(events.filter { action($0) == "first_prayer_logged" }.count == 1, "only a confirmedAt inside the trial counts, once")

        tracker.recordAlarmConfigured(status: status, settings: AlarmSettings(alarmsEnabled: true), now: dayOne)
        check(events.filter { action($0) == "alarm_configured" }.count == 1, "alarm milestone records once after valid configuration")

        let otherCustomer = TrialJourneyTracker(
            defaults: defaults,
            customerIDProvider: { "different-local-customer" },
            eventRecorder: { events.append(($0, $1)) }
        )
        otherCustomer.recordView(status: status, now: start)
        check(events.filter { $0.0 == .trialJourneyViewed }.count == 3, "customer identity scopes only local deduplication")

        let inactive = SubscriptionStatus(isActive: false, isInTrial: true, startDate: start, expiryDate: end, trialEndDate: end)
        tracker.recordView(status: inactive, now: start)
        check(events.filter { $0.0 == .trialJourneyViewed }.count == 3, "inactive status is ignored")
        print("PASS: trial journey UTC bucketing, local deduplication, and milestone checks")
    }

    private static func trialDay(_ event: (FunnelEvent, [String: Any])) -> Int? {
        event.1["trial_day"] as? Int
    }

    private static func action(_ event: (FunnelEvent, [String: Any])) -> String? {
        event.1["milestone"] as? String
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
