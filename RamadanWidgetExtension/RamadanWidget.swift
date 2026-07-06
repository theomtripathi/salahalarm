//
//  RamadanWidget.swift
//  RamadanWidgetExtension
//

import WidgetKit
import SwiftUI

private struct WidgetPrayerLog: Codable {
    var fajr: Bool = false
    var dhuhr: Bool = false
    var asr: Bool = false
    var maghrib: Bool = false
    var isha: Bool = false

    var prayedCount: Int { [fajr, dhuhr, asr, maghrib, isha].filter { $0 }.count }
}

private struct WidgetStreakData: Codable {
    var currentStreak: Int = 0
}

private struct SalahLockWidgetEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerTime: Date?
    let currentStreak: Int
    let todayConfirmedCount: Int
    let city: String
    let userName: String
    let prayerRows: [(String, Date, Bool)]
}

private struct SalahLockWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SalahLockWidgetEntry {
        sampleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SalahLockWidgetEntry) -> Void) {
        completion(loadEntry(for: Date()) ?? sampleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SalahLockWidgetEntry>) -> Void) {
        let now = Date()
        let entry = loadEntry(for: now) ?? sampleEntry(date: now)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry(for date: Date) -> SalahLockWidgetEntry? {
        guard WidgetConfig.loadIsSubscribed(),
              let location = WidgetConfig.loadLocation() else { return nil }

        let schedule = PrayerTimesCalculator.calculatePrayerTimes(for: date, location: location)
        let prayerLog = WidgetConfig.loadPrayerLog(for: DateFormatter.yyyyMMdd.string(from: date), as: WidgetPrayerLog.self) ?? WidgetPrayerLog()
        let streak = WidgetConfig.loadStreakData(as: WidgetStreakData.self)?.currentStreak ?? 0
        let userName = WidgetConfig.loadDisplayName()

        let prayers: [(String, Date, Bool)] = [
            ("Fajr", schedule.fajr, prayerLog.fajr),
            ("Dhuhr", schedule.dhuhr, prayerLog.dhuhr),
            ("Asr", schedule.asr, prayerLog.asr),
            ("Maghrib", schedule.maghrib, prayerLog.maghrib),
            ("Isha", schedule.isha, prayerLog.isha)
        ]

        let nextPrayer = prayers.first(where: { date < $0.1 }) ?? prayers.first

        return SalahLockWidgetEntry(
            date: date,
            nextPrayerName: nextPrayer?.0 ?? "Prayer",
            nextPrayerTime: nextPrayer?.1,
            currentStreak: streak,
            todayConfirmedCount: prayerLog.prayedCount,
            city: location.city,
            userName: userName,
            prayerRows: prayers
        )
    }

    private func sampleEntry(date: Date) -> SalahLockWidgetEntry {
        let calendar = Calendar.current
        return SalahLockWidgetEntry(
            date: date,
            nextPrayerName: "Dhuhr",
            nextPrayerTime: calendar.date(byAdding: .hour, value: 2, to: date),
            currentStreak: 7,
            todayConfirmedCount: 2,
            city: "Your City",
            userName: "Friend",
            prayerRows: [
                ("Fajr", calendar.date(bySettingHour: 5, minute: 12, second: 0, of: date) ?? date, true),
                ("Dhuhr", calendar.date(bySettingHour: 12, minute: 38, second: 0, of: date) ?? date, false),
                ("Asr", calendar.date(bySettingHour: 15, minute: 54, second: 0, of: date) ?? date, false),
                ("Maghrib", calendar.date(bySettingHour: 18, minute: 41, second: 0, of: date) ?? date, false),
                ("Isha", calendar.date(bySettingHour: 20, minute: 2, second: 0, of: date) ?? date, false)
            ]
        )
    }
}

struct RamadanWidget: Widget {
    let kind: String = "SalahAlarmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SalahLockWidgetProvider()) { entry in
            SalahLockWidgetEntryView(entry: entry)
                .widgetSurfaceBackground {
                    LinearGradient(
                        colors: [Color(hex: "#22A847"), Color(hex: "#157832")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("SalahAlarm")
        .description("See your streak and next prayer at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private extension View {
    @ViewBuilder
    func widgetSurfaceBackground<Background: View>(
        @ViewBuilder _ background: () -> Background
    ) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                background()
            }
        } else {
            self.background(background())
        }
    }
}

private struct SalahLockWidgetEntryView: View {
    let entry: SalahLockWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            largeWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            topLine
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🔥 \(entry.currentStreak)")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                    Text("day streak")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                }
                Spacer()
            }
            Spacer()
            nextPrayerBlock
        }
        .padding(14)
    }

    private var mediumWidget: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                topLine
                Text("🔥 \(entry.currentStreak)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                Text("day streak")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                Spacer()
                prayerDots
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                nextPrayerBlock
                Spacer()
                Text("\(entry.todayConfirmedCount) / 5 prayers today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .padding(14)
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                topLine
                Spacer()
                Text("\(entry.todayConfirmedCount) / 5 prayers")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5D56A"))
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔥 \(entry.currentStreak)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("day streak")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.82))
                }
                Spacer()
                nextPrayerBlock
            }

            prayerDots

            VStack(spacing: 8) {
                ForEach(Array(entry.prayerRows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.0)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(row.1.timeString(format: "h:mm a"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                        Circle()
                            .fill(row.2 ? Color(hex: "#1A9E3F") : Color.white.opacity(0.35))
                            .frame(width: 9, height: 9)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(14)
    }

    private var topLine: some View {
        HStack(spacing: 8) {
            Text(entry.city)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(entry.userName.isEmpty ? "SalahAlarm" : entry.userName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    private var nextPrayerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next Prayer")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
            Text(entry.nextPrayerName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#F5D56A"))
            Text(entry.nextPrayerTime?.timeString(format: "h:mm a") ?? "--")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var prayerDots: some View {
        HStack(spacing: 8) {
            ForEach(Array(entry.prayerRows.enumerated()), id: \.offset) { _, row in
                VStack(spacing: 5) {
                    Text(String(row.0.prefix(1)))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.82))
                    Circle()
                        .fill(row.2 ? Color(hex: "#1A9E3F") : Color.white.opacity(0.28))
                        .frame(width: 12, height: 12)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
