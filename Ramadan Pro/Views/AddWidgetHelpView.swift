//
//  AddWidgetHelpView.swift
//  Ramadan Pro
//
//  Created by Cursor on 2026-01-24.
//

import SwiftUI
import WidgetKit

struct AddWidgetHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { backgroundGeometry in
            ZStack {
                Image("background_image")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: backgroundGeometry.size.width, height: backgroundGeometry.size.height)
                
                Color.black.opacity(0.6)
            }
            .ignoresSafeArea()
            
            GeometryReader { contentGeometry in
                VStack(spacing: 0) {
                    header
                    
                    ScrollView {
                        VStack(spacing: 18) {
                            widgetPreviewCard
                            
                            stepsCard
                            
                            Button(action: {
                                WidgetCenter.shared.reloadAllTimelines()
                            }) {
                                Text("Refresh widget data")
                                    .font(.canela(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.customButtonColor)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                                    )
                            }
                            .padding(.top, 6)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
                .frame(width: contentGeometry.size.width, height: contentGeometry.size.height)
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("Add Widget")
                .font(.canela(size: 18, weight: .semibold))
                .foregroundColor(AppColors.customTextColor)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.customPlaceholderText)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }
    
    private var widgetPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.canela(size: 12, weight: .medium))
                .foregroundColor(AppColors.customPlaceholderText)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                )
                .frame(height: 140)
                .overlay(
                    VStack(spacing: 10) {
                        HStack {
                            Text("SalahAlarm")
                                .font(.canela(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.customTextColor)
                            Spacer()
                            Text("Next: Asr")
                                .font(.canela(size: 12, weight: .regular))
                                .foregroundColor(AppColors.customPlaceholderText)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Iftar in")
                                .font(.canela(size: 12, weight: .regular))
                                .foregroundColor(AppColors.customPlaceholderText)
                            Text("01:02:15")
                                .font(.canela(size: 32, weight: .bold))
                                .foregroundColor(AppColors.customTextColor)
                                .monospacedDigit()
                        }
                    }
                    .padding(16)
                )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                )
                .shadow(color: AppColors.customButtonColor.opacity(0.18), radius: 10, x: 0, y: 4)
        )
    }
    
    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to add it")
                .font(.canela(size: 14, weight: .semibold))
                .foregroundColor(AppColors.customTextColor)
            
            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: "1", text: "Long-press on your Home Screen.")
                stepRow(number: "2", text: "Tap the + button (top-left).")
                stepRow(number: "3", text: "Search “SalahAlarm”.")
                stepRow(number: "4", text: "Choose a size, then tap Add Widget.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                )
                .shadow(color: AppColors.customButtonColor.opacity(0.18), radius: 10, x: 0, y: 4)
        )
    }
    
    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppColors.customButtonColor)
                    .frame(width: 22, height: 22)
                Text(number)
                    .font(.canela(size: 12, weight: .bold))
                    .foregroundColor(.black)
            }
            
            Text(text)
                .font(.canela(size: 14, weight: .regular))
                .foregroundColor(AppColors.customPlaceholderText)
            
            Spacer()
        }
    }
}

#Preview {
    AddWidgetHelpView()
}
