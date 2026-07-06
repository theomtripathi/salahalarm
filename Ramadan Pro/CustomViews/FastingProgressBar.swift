//
//  FastingProgressBar.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Visual progress bar showing fasting progress throughout the day
struct FastingProgressBar: View {
    let progress: Double
    let status: FastingStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(height: 12)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * min(progress, 1.0), height: 12)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 12)
        }
    }
    
    private var statusText: String {
        switch status {
        case .notStarted:
            return "Fasting not started"
        case .fasting:
            return "Currently fasting"
        case .completed:
            return "Fasting completed"
        }
    }
    
    private var progressColor: Color {
        switch status {
        case .notStarted:
            return AppColors.textSecondary
        case .fasting:
            return AppColors.accent
        case .completed:
            return AppColors.accentDark
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        FastingProgressBar(progress: 0.0, status: .notStarted)
        FastingProgressBar(progress: 0.45, status: .fasting)
        FastingProgressBar(progress: 1.0, status: .completed)
    }
    .padding()
}
