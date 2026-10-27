//
//  PhoneUsageCalculator.swift
//  Ramadan Pro
//

import Foundation

struct PhoneUsageCalculator {
    static func stats(for range: PhoneUsageRange) -> (hours: Int, days: Int, years: Int) {
        switch range {
        case .r1_2: return (548, 23, 4)
        case .r2_3: return (912, 38, 6)
        case .r3_4: return (1277, 53, 9)
        case .r4_5: return (1642, 68, 11)
        case .r6plus: return (2372, 99, 16)
        default: return (0, 0, 0)
        }
    }
}
