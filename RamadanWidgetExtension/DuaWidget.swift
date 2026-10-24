//
//  DuaWidget.swift
//  RamadanWidgetExtension
//
//  A rotating dua / Quran & Hadith quote widget. The dua and the color
//  theme change every 30 minutes (and whenever the widget reloads).
//

import WidgetKit
import SwiftUI

struct DuaWidgetEntry: TimelineEntry {
    let date: Date
    let dua: Dua
    let theme: DuaTheme
}

struct DuaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DuaWidgetEntry {
        entry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DuaWidgetEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DuaWidgetEntry>) -> Void) {
        let now = Date()
        // One entry per 30-minute slot for the next 6 hours, aligned to the
        // current half-hour so each reload also lands on a fresh dua.
        let entries = DuaLibrary.timelineDuas(from: now, slots: 12).map {
            DuaWidgetEntry(date: $0.date, dua: $0.dua, theme: $0.theme)
        }
        let refresh = now.addingTimeInterval(6 * 3600)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func entry(for date: Date) -> DuaWidgetEntry {
        DuaWidgetEntry(date: date, dua: DuaLibrary.dua(for: date), theme: DuaLibrary.theme(for: date))
    }
}

struct DuaWidget: Widget {
    let kind: String = "SalahAlarmDuaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DuaWidgetProvider()) { entry in
            DuaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dua of the Moment")
        .description("A new dua from the Quran and Sunnah every 30 minutes.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryInline
        ])
    }
}

private extension View {
    @ViewBuilder
    func duaSurfaceBackground<Background: View>(
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

    /// Lock screen accessory widgets get the subtle system material instead
    /// of our color themes (iOS tints them monochrome anyway).
    @ViewBuilder
    func accessorySurfaceBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                AccessoryWidgetBackground()
            }
        } else {
            self
        }
    }
}

struct DuaWidgetEntryView: View {
    let entry: DuaWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var accent: Color { Color(duaHex: entry.theme.accentHex) }

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineWidget
                .accessorySurfaceBackground()
        case .accessoryRectangular:
            rectangularWidget
                .accessorySurfaceBackground()
        case .systemSmall:
            smallWidget
                .duaSurfaceBackground { themeGradient }
        case .systemMedium:
            mediumWidget
                .duaSurfaceBackground { themeGradient }
        default:
            largeWidget
                .duaSurfaceBackground { themeGradient }
        }
    }

    private var themeGradient: LinearGradient {
        LinearGradient(
            colors: [Color(duaHex: entry.theme.topHex), Color(duaHex: entry.theme.bottomHex)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Lock screen families

    /// One line next to the date, e.g. "🤲 My Lord, increase me in knowledge."
    private var inlineWidget: some View {
        Text("🤲 \(entry.dua.english)")
    }

    /// Rectangular widget under the clock. Lock screen renders it in the
    /// system tint, so it's text-only: the dua plus its reference.
    private var rectangularWidget: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.dua.english)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .minimumScaleFactor(0.75)
                .lineLimit(3)
            Text(entry.dua.reference)
                .font(.system(size: 10, weight: .medium))
                .opacity(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            Text(entry.dua.english)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(5)
            Spacer(minLength: 0)
            Text(entry.dua.reference)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(14)
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)
            Text(entry.dua.english)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(3)
            Text(entry.dua.arabic)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(entry.dua.reference)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Spacer(minLength: 0)
            Text("“\(entry.dua.english)”")
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(5)
            Rectangle()
                .fill(accent.opacity(0.5))
                .frame(width: 46, height: 1.5)
            Text(entry.dua.arabic)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .minimumScaleFactor(0.6)
                .lineLimit(4)
            Spacer(minLength: 0)
            HStack {
                Text(entry.dua.reference)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12))
                    .foregroundColor(accent.opacity(0.8))
            }
        }
        .padding(18)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "hands.and.sparkles.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(accent)
            Text("DUA OF THE MOMENT")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundColor(.white.opacity(0.75))
            Spacer(minLength: 0)
        }
    }
}

extension Color {
    init(duaHex: String) {
        let hex = duaHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
