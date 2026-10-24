import Foundation

@main
struct OnboardingJourneyTests {
    static func main() {
        var now = Date(timeIntervalSince1970: 1_000)
        var journey = OnboardingJourney(journeyID: "journey-test", now: { now })
        let first = journey.start(screen: "welcome", index: 1)
        now.addTimeInterval(4)
        let duplicateStart = journey.start(screen: "welcome", index: 1)
        check(duplicateStart.id == first.id, "repeated start preserves the current visit")
        now.addTimeInterval(12)
        journey.pause()
        now.addTimeInterval(600)
        journey.pause()
        journey.resume()
        journey.resume()
        now.addTimeInterval(5)
        let forward = journey.transition(to: "mechanism", index: 2, completed: true)!
        check(forward.previous.id == first.id && forward.elapsedActiveSeconds == 21 && forward.completed, "visit time accumulates across pause/resume, excluding background time")
        now.addTimeInterval(10)
        journey.pause()
        let pausedTotal = journey.activeSeconds
        now.addTimeInterval(60)
        check(journey.activeSeconds == pausedTotal, "inactive clock time does not accrue")
        journey.resume()
        now.addTimeInterval(5)
        let back = journey.transition(to: "welcome", index: 1, completed: false)!
        check(back.elapsedActiveSeconds == 15 && !back.completed, "revisited screen time accumulates and back is not completed")
        check(back.previous.id != first.id && journey.screensSeen.count == 2, "revisited screen receives a new visit while unique screens are counted")
        let revisit = journey.currentVisit!
        now.addTimeInterval(3)
        journey.pause()
        now.addTimeInterval(30)
        let beforeResume = journey.activeSeconds
        check(beforeResume == 36, "time remains frozen while journey is paused")
        journey.resume()
        now.addTimeInterval(2)
        let lastTransition = journey.transition(to: "mechanism", index: 2, completed: false)!
        check(lastTransition.previous.id == revisit.id && lastTransition.elapsedActiveSeconds == 5, "a later pause resumes the same visit and reports cumulative active visit time")
        let totals = journey.finish()
        check(totals.elapsedActiveSeconds == 41 && totals.screensSeenCount == 2, "finish reports total active time and distinct screens")
        check(OnboardingRouter.quickStartRoute == [.screen1, .screen3, .screen6, .screen7A, .screen8, .screen10, .screen17, .screen18], "canonical route excludes legacy screens")
        check(OnboardingScreenID.allCases.allSatisfy { !$0.analyticsName.isEmpty && $0.funnelIndex != nil }, "all persisted IDs have stable analytics names and indices")
        check([OnboardingScreenID.screen1, .screen3, .screen6, .screen7A, .screen8, .screen10, .screen17, .screen18].compactMap(\.funnelIndex) == Array(1...8), "canonical route has ordered v4 funnel indices")
        check(OnboardingScreenID.screen4.analyticsName == "legacy_prayer_frequency" && OnboardingScreenID.screen5.analyticsName == "legacy_phone_usage" && OnboardingScreenID.screen16A.analyticsName == "legacy_lock_intro", "legacy names match their actual rendered screens")
        check(OnboardingRouter.progress(for: .screen1) == 0.125 && OnboardingRouter.progress(for: .screen18) == 1, "active route progress derives from route length")
        check(OnboardingRouter.next(after: .screen2) == .screen3 && OnboardingRouter.previous(before: .screen2) == .screen1, "legacy IDs resolve to navigable quick-start neighbors")
        print("PASS: onboarding journey timing, visit identity, route, and legacy analytics")
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
