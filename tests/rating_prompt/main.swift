import Foundation

private func expect(
    _ actual: RatingPromptPolicy.Decision,
    _ expected: RatingPromptPolicy.Decision,
    _ message: String
) {
    guard actual == expected else {
        fatalError("\(message): expected \(expected), got \(actual)")
    }
}

@main
struct RatingPromptTests {
static func main() {
let firstUse = Date(timeIntervalSince1970: 1_000_000)
let exactlyOneDayLater = firstUse.addingTimeInterval(RatingPromptPolicy.minimumEligibleUseAge)

for entitlementKind in ["paid", "trial"] {
    expect(
        RatingPromptPolicy.decision(
            now: exactlyOneDayLater,
            firstEligibleUse: firstUse,
            didRequest: false,
            hasActiveEntitlement: true,
            isForeground: true,
            isModalPresented: false
        ),
        .request,
        "active \(entitlementKind) entitlement qualifies at exactly 24 elapsed hours"
    )
}

expect(
    RatingPromptPolicy.decision(
        now: firstUse,
        firstEligibleUse: nil,
        didRequest: false,
        hasActiveEntitlement: true,
        isForeground: true,
        isModalPresented: false
    ),
    .establishFirstEligibleUse,
    "first eligible use establishes baseline instead of prompting"
)

expect(
    RatingPromptPolicy.decision(
        now: exactlyOneDayLater.addingTimeInterval(-1),
        firstEligibleUse: firstUse,
        didRequest: false,
        hasActiveEntitlement: true,
        isForeground: true,
        isModalPresented: false
    ),
    .waitForOneDay,
    "less than 24 elapsed hours does not qualify"
)

expect(
    RatingPromptPolicy.decision(
        now: exactlyOneDayLater,
        firstEligibleUse: firstUse,
        didRequest: false,
        hasActiveEntitlement: true,
        isForeground: false,
        isModalPresented: false
    ),
    .notForeground,
    "elapsed time alone does not trigger without a foreground return"
)

for ineligibleStatus in ["expired", "unpaid", "admin bypass"] {
    expect(
        RatingPromptPolicy.decision(
            now: exactlyOneDayLater,
            firstEligibleUse: firstUse,
            didRequest: false,
            hasActiveEntitlement: false,
            isForeground: true,
            isModalPresented: false
        ),
        .notEntitled,
        "\(ineligibleStatus) status is not a live active entitlement"
    )
}

expect(
    RatingPromptPolicy.decision(
        now: exactlyOneDayLater,
        firstEligibleUse: firstUse,
        didRequest: false,
        hasActiveEntitlement: true,
        isForeground: true,
        isModalPresented: true
    ),
    .modalPresented,
    "modal defers the request"
)

expect(
    RatingPromptPolicy.decision(
        now: exactlyOneDayLater,
        firstEligibleUse: firstUse,
        didRequest: false,
        hasActiveEntitlement: true,
        isForeground: true,
        isModalPresented: false
    ),
    .request,
    "a later eligible foreground return can request after modal deferral"
)

expect(
    RatingPromptPolicy.decision(
        now: exactlyOneDayLater,
        firstEligibleUse: firstUse,
        didRequest: true,
        hasActiveEntitlement: true,
        isForeground: true,
        isModalPresented: false
    ),
    .alreadyRequested,
    "existing global did-request migration state is respected"
)

print("Rating prompt policy tests passed")
}
}
