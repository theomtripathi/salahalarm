//
//  PrayerHistoryView.swift
//  Ramadan Pro
//

import SwiftUI

struct PrayerHistoryView: View {
    @ObservedObject private var prayerLogViewModel = PrayerLogViewModel.shared
    @StateObject private var internalPrayerTimesViewModel = PrayerTimesViewModel()
    @State private var selectedWeekOffset = 0
    @State private var showingMonthly = false

    let externalPrayerTimesViewModel: PrayerTimesViewModel?

    init(prayerTimesViewModel: PrayerTimesViewModel? = nil) {
        self.externalPrayerTimesViewModel = prayerTimesViewModel
    }

    private var prayerTimesViewModel: PrayerTimesViewModel {
        externalPrayerTimesViewModel ?? internalPrayerTimesViewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(L10n.text("Prayer History"))
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    SLStreakBadge(streak: prayerLogViewModel.streakData.currentStreak, isActive: prayerLogViewModel.todayConfirmedCount > 0)
                }

                summaryCards
                weeklyOrMonthlySection
                prayerLogList
            }
            .padding(20)
        }
        .background(AppColors.slCream.ignoresSafeArea())
        .task {
            await prayerTimesViewModel.loadPrayerTimes()
            await prayerLogViewModel.load()
        }
    }

    private var summaryCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                compactCard("🔥", "\(prayerLogViewModel.streakData.currentStreak)", L10n.text("day streak"))
                compactCard("🕌", "\(prayerLogViewModel.streakData.totalPrayersConfirmed)", L10n.text("prayers total"))
                compactCard("📅", "\(prayerLogViewModel.streakData.totalPrayerDays)", L10n.text("full days"))
                compactCard("⏱", String(format: "%.1f", Double(prayerLogViewModel.streakData.totalPrayersConfirmed * 10) / 60.0), L10n.text("hours in salah"))
            }
        }
    }

    private var weeklyOrMonthlySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker(L10n.text("View"), selection: $showingMonthly) {
                    Text(L10n.text("Weekly")).tag(false)
                    Text(L10n.text("Monthly")).tag(true)
                }
                .pickerStyle(.segmented)

                Spacer()

                Button {
                    selectedWeekOffset -= 1
                } label: {
                    Image(systemName: "chevron.backward")
                }
                Button {
                    selectedWeekOffset += 1
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(selectedWeekOffset >= 0)
            }

            if showingMonthly {
                monthlyCalendar
            } else {
                weeklyHeatmap
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var weeklyHeatmap: some View {
        let days = displayedWeek
        return VStack(spacing: 10) {
            ForEach(PrayerName.allCases, id: \.self) { prayer in
                HStack {
                    Text(L10n.text(prayer.shortLabel))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 48, alignment: .leading)
                    ForEach(days, id: \.self) { day in
                        let log = prayerLogViewModel.log(for: day)
                        Circle()
                            .fill(circleColor(for: prayer, day: day, log: log))
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(AppColors.slBorderDefault, lineWidth: 1))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var monthlyCalendar: some View {
        let days = monthDays
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
            ForEach(days, id: \.self) { day in
                let log = prayerLogViewModel.log(for: day)
                VStack(spacing: 6) {
                    Text("\(Calendar.current.component(.day, from: day))")
                        .font(.system(size: 12, weight: .medium))
                    Circle()
                        .fill(dayColor(log: log, day: day))
                        .frame(width: 10, height: 10)
                }
                .frame(maxWidth: .infinity, minHeight: 38)
            }
        }
    }

    private var prayerLogList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Recent Prayer Log"))
                .font(.system(size: 18, weight: .bold))
            ForEach(recentDates, id: \.self) { day in
                let log = prayerLogViewModel.log(for: day)
                HStack {
                    Text(day.formattedDate("EEE, MMM d"))
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(PrayerName.allCases, id: \.self) { prayer in
                            Text(log.isConfirmed(prayer) ? "✅" : "•")
                                .foregroundColor(log.isConfirmed(prayer) ? AppColors.slGreen : AppColors.slTabUnselected)
                        }
                    }
                    Text("\(log.prayedCount)/5")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.slGold)
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            }
        }
    }

    private func compactCard(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 8) {
            Text(emoji).font(.system(size: 24))
            Text(value)
                .font(.system(size: 20, weight: .bold))
            Text(L10n.text(label))
                .font(.system(size: 11))
                .foregroundColor(AppColors.slTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 92, height: 92)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private var displayedWeek: [Date] {
        let base = Calendar.current.date(byAdding: .day, value: selectedWeekOffset * 7, to: Date()) ?? Date()
        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: base) ?? DateInterval(start: Date(), duration: 7 * 86400)
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var monthDays: [Date] {
        let monthInterval = Calendar.current.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), duration: 30 * 86400)
        let days = Calendar.current.range(of: .day, in: .month, for: monthInterval.start) ?? 1..<31
        return days.compactMap { Calendar.current.date(byAdding: .day, value: $0 - 1, to: monthInterval.start) }
    }

    private var recentDates: [Date] {
        (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
    }

    private func circleColor(for prayer: PrayerName, day: Date, log: DailyPrayerLog) -> Color {
        if log.isConfirmed(prayer) { return AppColors.slGreen }
        return day < Date().startOfDay ? Color(hex: "#FFE5E5") : .clear
    }

    private func dayColor(log: DailyPrayerLog, day: Date) -> Color {
        if day > Date() { return AppColors.slBorderDefault }
        switch log.prayedCount {
        case 5: return AppColors.slGreen
        case 3...4: return AppColors.slGold
        case 1...2: return .orange
        default: return .red
        }
    }
}

#Preview {
    PrayerHistoryView()
}
