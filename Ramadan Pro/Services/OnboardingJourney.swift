import Foundation

struct OnboardingJourney {
    struct Visit {
        let id: String
        let screen: String
        let index: Int
        let startedAt: Date
    }
    struct Transition {
        let previous: Visit
        let elapsedActiveSeconds: Int
        let completed: Bool
    }

    let journeyID: String
    private let now: () -> Date
    private(set) var activeSeconds: TimeInterval = 0
    private(set) var isActive = false
    private(set) var currentVisit: Visit?
    private(set) var screensSeen: Set<String> = []
    private var activeSince: Date?
    private var startedAt: Date?
    private var currentVisitActiveSeconds: TimeInterval = 0

    init(journeyID: String = UUID().uuidString, now: @escaping () -> Date = Date.init) {
        self.journeyID = journeyID
        self.now = now
    }

    mutating func start(screen: String, index: Int) -> Visit {
        if let currentVisit, currentVisit.screen == screen {
            if !isActive { resume() }
            return currentVisit
        }
        if startedAt == nil { startedAt = now() }
        if currentVisit != nil {
            _ = transition(to: screen, index: index, completed: false)
            return currentVisit!
        }
        resume()
        return enter(screen: screen, index: index)
    }

    mutating func transition(to screen: String, index: Int, completed: Bool) -> Transition? {
        guard let previous = currentVisit else { return nil }
        currentVisitActiveSeconds += closeActiveInterval()
        let result = Transition(previous: previous, elapsedActiveSeconds: Int(currentVisitActiveSeconds.rounded()), completed: completed)
        _ = enter(screen: screen, index: index)
        currentVisitActiveSeconds = 0
        if isActive { activeSince = now() }
        return result
    }

    mutating func pause() {
        currentVisitActiveSeconds += closeActiveInterval()
        isActive = false
    }
    mutating func resume() { guard !isActive else { return }; isActive = true; activeSince = now() }

    mutating func finish() -> (elapsedActiveSeconds: Int, screensSeenCount: Int) {
        currentVisitActiveSeconds += closeActiveInterval()
        isActive = false
        return (Int(activeSeconds.rounded()), screensSeen.count)
    }

    private mutating func closeActiveInterval() -> TimeInterval {
        guard isActive, let activeSince else { return 0 }
        let elapsed = max(0, now().timeIntervalSince(activeSince))
        activeSeconds += elapsed
        self.activeSince = nil
        return elapsed
    }

    private mutating func enter(screen: String, index: Int) -> Visit {
        let visit = Visit(id: UUID().uuidString, screen: screen, index: index, startedAt: now())
        currentVisit = visit
        screensSeen.insert(screen)
        return visit
    }
}
