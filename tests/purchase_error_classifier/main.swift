import Foundation
import StoreKit

let rcDomain = "RevenueCat.ErrorCode"
let fixtureCodes = PurchaseErrorClassifier.RevenueCatCodes(
    cancelled: 101,
    pending: 120,
    purchaseNotAllowed: 103,
    insufficientPermissions: 119
)
func expect(_ actual: PurchaseErrorClassifier.Result, _ expected: PurchaseErrorClassifier.Result, _ label: String) {
    guard actual == expected else {
        fputs("FAIL: \(label): got \(actual), expected \(expected)\n", stderr)
        exit(1)
    }
    print("PASS: \(label)")
}

func classify(_ error: NSError) -> PurchaseErrorClassifier.Result {
    PurchaseErrorClassifier.classify(error, revenueCatErrorDomain: rcDomain, revenueCatCodes: fixtureCodes)
}

expect(classify(NSError(domain: rcDomain, code: fixtureCodes.purchaseNotAllowed)), .notAllowed, "RevenueCat purchaseNotAllowed fixture")
expect(classify(NSError(domain: rcDomain, code: fixtureCodes.insufficientPermissions)), .notAllowed, "RevenueCat insufficientPermissions fixture")
expect(classify(NSError(domain: SKErrorDomain, code: SKError.paymentNotAllowed.rawValue)), .notAllowed, "underlying StoreKit paymentNotAllowed")
expect(classify(NSError(domain: rcDomain, code: fixtureCodes.cancelled)), .cancelled, "RevenueCat purchaseCancelled fixture")
expect(classify(NSError(domain: SKErrorDomain, code: SKError.paymentCancelled.rawValue)), .cancelled, "StoreKit paymentCancelled")
expect(classify(NSError(domain: rcDomain, code: fixtureCodes.pending)), .pending, "RevenueCat paymentPending fixture")
expect(classify(NSError(domain: rcDomain, code: 3)), .failed, "unconfigured RevenueCat code is not guessed")
expect(classify(NSError(domain: "StoreKitTest", code: 1001)), .failed, "unclassified error is not a decline")

let wrappedPermissionError = NSError(
    domain: "RevenueCat.Wrapper",
    code: -1,
    userInfo: [NSUnderlyingErrorKey: NSError(domain: SKErrorDomain, code: SKError.paymentNotAllowed.rawValue)]
)
expect(classify(wrappedPermissionError), .notAllowed, "wrapped StoreKit permission restriction")

var overDepthError = NSError(domain: SKErrorDomain, code: SKError.paymentNotAllowed.rawValue)
for _ in 0..<9 {
    overDepthError = NSError(domain: "Wrapper", code: 1, userInfo: [NSUnderlyingErrorKey: overDepthError])
}
expect(classify(overDepthError), .failed, "underlying traversal stops at depth limit")
print("All purchase error classifier tests passed.")
