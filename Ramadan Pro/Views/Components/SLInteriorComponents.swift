//
//  SLInteriorComponents.swift
//  Ramadan Pro
//

import SwiftUI

struct SLStreakBadge: View {
    let streak: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundColor(isActive ? AppColors.slGold : AppColors.slTabUnselected)
            if streak > 0 {
                Text("\(streak)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isActive ? AppColors.slGold : AppColors.slTabUnselected)
            } else {
                Text("start your streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.slTextSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct PrayerConfirmationVerse {
    let quote: String
    let attribution: String

    static let rotation: [PrayerConfirmationVerse] = [
        .init(quote: "Establish prayer and give zakah, and bow with those who bow.", attribution: "Quran 2:43"),
        .init(quote: "Indeed, prayer prohibits immorality and wrongdoing.", attribution: "Quran 29:45"),
        .init(quote: "Seek help through patience and prayer.", attribution: "Quran 2:45"),
        .init(quote: "And establish prayer for My remembrance.", attribution: "Quran 20:14"),
        .init(quote: "Successful indeed are the believers, those who are humble in their prayer.", attribution: "Quran 23:1-2")
    ]

    static func todaysVerse() -> PrayerConfirmationVerse {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return rotation[day % rotation.count]
    }
}

struct SLPrayerConfirmationSheet: View {
    let prayer: PrayerName
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        let verse = PrayerConfirmationVerse.todaysVerse()
        VStack(spacing: 20) {
            Capsule()
                .fill(AppColors.slBorderDefault)
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            SalahLockBrandMark(size: 40)

            VStack(spacing: 6) {
                Text(L10n.format("Did you pray %@?", L10n.text(prayer.displayName)))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(prayer.arabicName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.slGold)
            }

            SLQuoteCard(quote: verse.quote, attribution: verse.attribution)

            VStack(spacing: 12) {
                SLPrimaryButton(title: "i prayed 🤲", action: onConfirm)
                SLSecondaryButton(title: "not yet", action: onDismiss)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(Color.white)
    }
}
