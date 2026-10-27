import Foundation

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else { fatalError("FAIL: \(message)") }
}

check(AnnualTrialOfferPolicy.isAnnual(unit: .year, value: 1), "one year")
check(AnnualTrialOfferPolicy.isAnnual(unit: .month, value: 12), "twelve months")
for (unit, value) in [(AnnualTrialOfferPolicy.Unit.month, 1), (.week, 52), (.day, 365), (.year, 2), (.unknown, 1)] {
    check(!AnnualTrialOfferPolicy.isAnnual(unit: unit, value: value), "reject nonannual or unknown period")
}
check(AnnualTrialOfferPolicy.isSevenDayFreeTrial(unit: .day, value: 7, periods: 1, isFreeTrial: true, introductoryPrice: 0), "seven days")
check(AnnualTrialOfferPolicy.isSevenDayFreeTrial(unit: .week, value: 1, periods: 1, isFreeTrial: true, introductoryPrice: 0), "one week")
for (unit, value, periods, free, price) in [
    (AnnualTrialOfferPolicy.Unit.day, 14, 1, true, Decimal(0)),
    (.day, 7, 2, true, 0), (.week, 2, 1, true, 0),
    (.day, 7, 1, false, 0), (.day, 7, 1, true, Decimal(1)),
    (.month, 1, 1, true, 0), (.unknown, 7, 1, true, 0)
] {
    check(!AnnualTrialOfferPolicy.isSevenDayFreeTrial(unit: unit, value: value, periods: periods, isFreeTrial: free, introductoryPrice: price), "reject mismatched/free-price terms")
}
check(AnnualTrialOfferPolicy.hasRenewalPrice(19.99, currency: "USD"), "live positive price")
check(!AnnualTrialOfferPolicy.hasRenewalPrice(0, currency: "USD"), "zero renewal")
check(!AnnualTrialOfferPolicy.hasRenewalPrice(.nan, currency: "USD"), "NaN renewal")
check(!AnnualTrialOfferPolicy.hasRenewalPrice(.infinity, currency: "USD"), "infinite renewal")
check(!AnnualTrialOfferPolicy.hasRenewalPrice(19.99, currency: nil), "unknown currency")
check(!AnnualTrialOfferPolicy.hasRenewalPrice(19.99, currency: ""), "empty currency")

let trial = SubscriptionPlanDetails(type: .yearly, price: 19.99, priceString: "$19.99", currencyCode: "USD", productId: "yearlydiscountedtrial", billingPeriodLabel: "year", introductoryTrialDays: 7)
check(trial.trialLabel == "7-day free trial", "trial label")
check(trial.renewalDescription == "Then $19.99 / year. Cancel anytime.", "real annual renewal label")
let roundedMonthly = NumberFormatter()
roundedMonthly.numberStyle = .currency
roundedMonthly.locale = Locale(identifier: "en_US")
roundedMonthly.currencyCode = "USD"
check(roundedMonthly.string(from: NSNumber(value: trial.price / 12)) == "$1.67", "monthly equivalent rounds, never truncates")
let rupee = SubscriptionPlanDetails(type: .yearly, price: 1999, priceString: "₹1,999", currencyCode: "INR")
check(rupee.formatAmount(rupee.price / 12).contains("₹"), "localized INR equivalent")
check(!rupee.formatAmount(rupee.price / 12).contains("$"), "no USD substitute for INR")
check(rupee.trialLabel == nil, "no free claim without verified metadata")
let decoded = try JSONDecoder().decode(SubscriptionPlanDetails.self, from: JSONEncoder().encode(trial))
check(decoded.introductoryTrialDays == 7, "trial Codable roundtrip")
let oldData = try JSONSerialization.jsonObject(with: JSONEncoder().encode(trial)) as! [String: Any]
var legacyData = oldData
legacyData.removeValue(forKey: "introductoryTrialDays")
let legacy = try JSONDecoder().decode(SubscriptionPlanDetails.self, from: JSONSerialization.data(withJSONObject: legacyData))
check(legacy.trialLabel == nil, "old cached plan never invents a trial")
print("PASS: \(checks) annual-trial policy/pricing checks")
