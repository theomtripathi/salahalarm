//
//  SLComponents.swift
//  Ramadan Pro
//

import SwiftUI

enum SLAuthProvider {
    case google
    case apple
    case email

    var title: String {
        switch self {
        case .google: return L10n.text("Continue with Google")
        case .apple: return L10n.text("Continue with Apple")
        case .email: return L10n.text("Continue with Email")
        }
    }

    var iconName: String {
        switch self {
        case .google: return "google_icon"
        case .apple: return "apple.logo"
        case .email: return "envelope.fill"
        }
    }
}

struct SLProgressBar: View {
    let progress: Double?

    var body: some View {
        if let progress {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.slGold.opacity(0.18))
                    Rectangle()
                        .fill(AppColors.slProgressBar)
                        .frame(width: geometry.size.width * min(max(progress, 0), 1))
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 3)
        }
    }
}

struct SLPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var backgroundColor: Color = AppColors.slGreen
    var foregroundColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isEnabled ? backgroundColor : Color(hex: "#CCCCCC"))
                if isLoading {
                    ProgressView().tint(foregroundColor)
                } else {
                    Text(L10n.text(title))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(foregroundColor)
                }
            }
            .frame(height: 56)
        }
        .disabled(!isEnabled || isLoading)
    }
}

struct SLSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(L10n.text(title))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.slGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.slGreen, lineWidth: 1)
                )
        }
    }
}

struct SLOptionPill: View {
    let emoji: String?
    let title: String
    let subtitle: String?
    let isSelected: Bool
    var isDisabled: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
                    Text(L10n.text(title))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.slTextPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(L10n.text(subtitle))
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.slTextSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.slGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: subtitle == nil ? 56 : 72)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.slBorderSelected : AppColors.slBorderDefault, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}

struct SLQuoteCard: View {
    let quote: String
    let attribution: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text(quote))
                .font(.system(size: 15))
                .italic()
                .foregroundColor(AppColors.slTextSecondary)
            Text(L10n.text(attribution))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.slGold)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AppColors.slGreen)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

struct SLStatCard: View {
    let label: String
    let value: String
    let sublabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text(label))
                .font(.system(size: 13))
                .foregroundColor(AppColors.slTextSecondary)
            if let sublabel {
                Text(L10n.text(sublabel))
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.slTextSecondary)
            }
            Text(L10n.text(value))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct SLSummaryCard: View {
    let sectionLabel: String
    let content: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text(sectionLabel))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.slGreen)
            ForEach(content, id: \.self) { item in
                Text(content.count > 1 ? "• \(L10n.text(item))" : L10n.text(item))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.slTextPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct SLAuthButton: View {
    let provider: SLAuthProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Group {
                    if provider == .google {
                        Image(provider.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(provider == .email ? AppColors.slGreen : .black)
                    }
                }
                .frame(width: 28)
                Spacer()
                Text(provider.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.slTextPrimary)
                Spacer()
                Color.clear.frame(width: 28, height: 20)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.slBorderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SLFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.slGreen)
                Group {
                    if icon.count == 1 || icon.first?.isEmojiPresentation == true {
                        Text(icon).font(.system(size: 18))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text(title))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(L10n.text(description))
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)
            }
            Spacer()
        }
    }
}

struct SLNotificationPreviewCard: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("SalahAlarm")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(L10n.text(message))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.92))
            }
            Spacer()
            Text("now")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.88))
        )
    }
}

struct SLTimelineRow: View {
    let number: Int
    let title: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppColors.slGreen)
                    Text("\(number)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 32)
                if !isLast {
                    Rectangle()
                        .fill(AppColors.slGreen.opacity(0.3))
                        .frame(width: 2, height: 34)
                }
            }
            Text(L10n.text(title))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.slTextPrimary)
                .padding(.top, 4)
            Spacer()
        }
    }
}

struct SalahLockBrandMark: View {
    var size: CGFloat = 96
    var body: some View {
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.14), radius: size * 0.08, x: 0, y: size * 0.03)
    }
}

struct KeyholeShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.width))
            path.addRoundedRect(in: CGRect(x: rect.midX - rect.width * 0.18, y: rect.midY - rect.height * 0.02, width: rect.width * 0.36, height: rect.height * 0.5), cornerSize: CGSize(width: rect.width * 0.18, height: rect.width * 0.18))
        }
    }
}

struct SalahLockGraphCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("relationship with salah")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.slTextPrimary)
                        Text("✕ skipped prayers")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    Spacer()
                    VStack(spacing: 6) {
                        SalahLockBrandMark(size: 44)
                        Text("salahalarm")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.slTextPrimary)
                        Text("prayer\njourney")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.slGold)
                            .multilineTextAlignment(.center)
                    }
                }
                ZStack {
                    GeometryReader { geometry in
                        let w = geometry.size.width
                        let h = geometry.size.height
                        Path { path in
                            path.move(to: CGPoint(x: w * 0.04, y: h * 0.72))
                            path.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.58), control: CGPoint(x: w * 0.12, y: h * 0.66))
                            path.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.46), control: CGPoint(x: w * 0.28, y: h * 0.44))
                            path.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.26), control: CGPoint(x: w * 0.62, y: h * 0.44))
                            path.addQuadCurve(to: CGPoint(x: w * 0.96, y: h * 0.12), control: CGPoint(x: w * 0.88, y: h * 0.18))
                        }
                        .stroke(Color(hex: "#D89A24"), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                        Path { path in
                            path.move(to: CGPoint(x: w * 0.04, y: h * 0.9))
                            path.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.82), control: CGPoint(x: w * 0.12, y: h * 0.78))
                            path.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.86), control: CGPoint(x: w * 0.3, y: h * 0.95))
                            path.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.72), control: CGPoint(x: w * 0.46, y: h * 0.78))
                            path.addQuadCurve(to: CGPoint(x: w * 0.68, y: h * 0.8), control: CGPoint(x: w * 0.6, y: h * 0.98))
                            path.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.84), control: CGPoint(x: w * 0.78, y: h * 0.7))
                            path.addQuadCurve(to: CGPoint(x: w * 0.96, y: h * 0.95), control: CGPoint(x: w * 0.93, y: h * 0.92))
                        }
                        .stroke(Color.red.opacity(0.65), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                        let goldPoints: [(CGFloat, CGFloat, String)] = [
                            (0.08, 0.71, "locked\nphone"),
                            (0.42, 0.46, "prayed\non time"),
                            (0.8, 0.26, "discipline\nbuilt"),
                            (0.96, 0.12, "")
                        ]
                        ForEach(0..<goldPoints.count, id: \.self) { idx in
                            let point = goldPoints[idx]
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: "#D89A24"))
                                    .frame(width: idx == 3 ? 14 : 34, height: idx == 3 ? 14 : 34)
                                    .overlay {
                                        if idx < 3 {
                                            Image(systemName: idx == 0 ? "lock.fill" : idx == 1 ? "checkmark.circle.fill" : "star.fill")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                if !point.2.isEmpty {
                                    Text(point.2)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color(hex: "#D89A24"))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .position(x: w * point.0, y: h * point.1)
                        }

                        let redPoints: [(CGFloat, CGFloat, String)] = [
                            (0.26, 0.83, "missed fajr"),
                            (0.55, 0.72, "i'll pray later"),
                            (0.68, 0.78, "just one\nmore scroll"),
                            (0.88, 0.84, "shaytan\nwon again")
                        ]
                        ForEach(0..<redPoints.count, id: \.self) { idx in
                            let point = redPoints[idx]
                            VStack(spacing: 6) {
                                Text(point.2)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.red.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                Circle()
                                    .fill(Color.red.opacity(0.82))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .position(x: w * point.0, y: h * point.1)
                        }

                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.black.opacity(0.75))
                                .frame(height: 2)
                        }

                        HStack {
                            Text("week 1")
                            Spacer()
                            Text("week 2")
                            Spacer()
                            Text("week 3")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.slTextPrimary)
                        .position(x: w / 2, y: h * 0.96)
                    }
                }
                .frame(height: 170)
                Text("your phone can either pull you away...\nor help you stay consistent.")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.slTextPrimary)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }
}

private extension Character {
    var isEmojiPresentation: Bool {
        unicodeScalars.first?.properties.isEmojiPresentation ?? false
    }
}
