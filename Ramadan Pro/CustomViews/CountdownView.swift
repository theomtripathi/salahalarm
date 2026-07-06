//
//  CountdownView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Displays a countdown timer with hours, minutes, and seconds
struct CountdownView: View {
    let timeInterval: TimeInterval?
    let label: String
    let primaryColor: Color
    
    @State private var displayedTime: String = "00:00:00"
    @State private var timer: Timer?
    
    init(timeInterval: TimeInterval?, label: String, primaryColor: Color = .primary) {
        self.timeInterval = timeInterval
        self.label = label
        self.primaryColor = primaryColor
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            
            Text(displayedTime)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(primaryColor)
                .monospacedDigit()
        }
        .onAppear {
            updateTime()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: timeInterval) { _ in
            updateTime()
        }
    }
    
    private func updateTime() {
        guard let interval = timeInterval, interval > 0 else {
            displayedTime = "00:00:00"
            return
        }
        
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        displayedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func startTimer() {
        timer?.invalidate() // Stop any existing timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTime()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    VStack(spacing: 20) {
        CountdownView(timeInterval: 3600, label: "Until Iftar")
        CountdownView(timeInterval: 7200, label: "Until Imsak", primaryColor: .blue)
    }
    .padding()
}
