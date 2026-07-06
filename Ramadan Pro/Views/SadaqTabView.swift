//
//  SadaqTabView.swift
//  Ramadan Pro
//

import SwiftUI

struct SadaqTabView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.system(size: 36))
                .foregroundColor(AppColors.slTabUnselected)
            Text("This feature has been removed.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.slTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.slCream.ignoresSafeArea())
    }
}

#Preview {
    SadaqTabView()
}
