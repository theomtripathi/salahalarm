//
//  SLSpinWheelView.swift
//  Ramadan Pro
//
//  Discount spin wheel for the paywall loop. One spin, always lands on the
//  "bumper deal" segment (the yearly package), then hands control back.
//

import SwiftUI

struct SLSpinWheelView: View {
    /// Called ~half a second after the wheel settles on the winning segment.
    let onWon: () -> Void

    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var hasLanded = false

    private struct Segment {
        let label: String
        let color: Color
    }

    // Segment 1 (60°–120° from the top) is the winner.
    private let segments: [Segment] = [
        Segment(label: "5% OFF", color: Color(hex: "#2E3A8C")),
        Segment(label: "🎁 BUMPER\nDEAL", color: Color(hex: "#1A9E3F")),
        Segment(label: "10% OFF", color: Color(hex: "#7A4A21")),
        Segment(label: "DUA PACK", color: Color(hex: "#0F6E6B")),
        Segment(label: "15% OFF", color: Color(hex: "#701C33")),
        Segment(label: "BARAKAH", color: Color(hex: "#4A2C6D"))
    ]

    private let winningIndex = 1
    private let spinDuration: Double = 3.2

    var body: some View {
        VStack(spacing: 26) {
            ZStack(alignment: .top) {
                wheel
                    .rotationEffect(.degrees(rotation))
                    .frame(width: 280, height: 280)

                // Pointer
                Triangle()
                    .fill(AppColors.slGold)
                    .frame(width: 30, height: 26)
                    .rotationEffect(.degrees(180))
                    .offset(y: -8)
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
            }

            SLPrimaryButton(title: hasLanded ? "you won! 🎉" : (isSpinning ? "spinning..." : "spin the wheel"), isEnabled: !isSpinning && !hasLanded) {
                spin()
            }
        }
    }

    private var wheel: some View {
        ZStack {
            ForEach(segments.indices, id: \.self) { index in
                let sliceAngle = 360.0 / Double(segments.count)
                WheelSlice(
                    startDegreesFromTop: Double(index) * sliceAngle,
                    sweepDegrees: sliceAngle
                )
                .fill(segments[index].color)

                Text(segments[index].label)
                    .font(.system(size: 13, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .frame(width: 76)
                    .offset(y: -86)
                    .rotationEffect(.degrees(Double(index) * sliceAngle + sliceAngle / 2))
            }

            Circle()
                .stroke(Color.white, lineWidth: 6)
            Circle()
                .fill(Color.white)
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: "gift.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.slGreen)
                )
                .shadow(color: .black.opacity(0.15), radius: 4)
        }
    }

    private func spin() {
        guard !isSpinning else { return }
        isSpinning = true

        // Land the winning segment's center under the top pointer:
        // its center sits at (winningIndex + 0.5) * slice degrees from the top,
        // so rotate the wheel by 360 - that, plus four full turns for drama.
        let sliceAngle = 360.0 / Double(segments.count)
        let winningCenter = (Double(winningIndex) + 0.5) * sliceAngle
        let target = 4 * 360.0 + (360.0 - winningCenter)

        withAnimation(.timingCurve(0.12, 0.75, 0.25, 1.0, duration: spinDuration)) {
            rotation = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration + 0.15) {
            hasLanded = true
            isSpinning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onWon()
            }
        }
    }
}

/// A pie slice measured clockwise from 12 o'clock.
private struct WheelSlice: Shape {
    let startDegreesFromTop: Double
    let sweepDegrees: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegreesFromTop - 90),
            endAngle: .degrees(startDegreesFromTop + sweepDegrees - 90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
