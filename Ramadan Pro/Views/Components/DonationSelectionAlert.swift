//
//  DonationSelectionAlert.swift
//  Ramadan Pro
//
//  Created by Cursor on 2026-01-24.
//

import SwiftUI
import RevenueCat

/// Custom alert for selecting donation amount in onboarding flow
struct DonationSelectionAlert: View {
    @Binding var isPresented: Bool
    @State private var selectedProductId: String? = nil
    @State private var availableProducts: [DonationProduct] = []
    @State private var isLoading: Bool = false
    @State private var showValidationError: Bool = false
    @State private var isProcessing: Bool = false
    @State private var showDropdown: Bool = false
    
    let onDonate: (String) async -> Void
    let onDonateLater: () -> Void
    
    var body: some View {
        ZStack {
            backgroundView
                .onTapGesture {
                    // Close dropdown when tapping background
                    if showDropdown {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showDropdown = false
                        }
                    }
                }
            
            alertContentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task {
            await loadDonationProducts()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var backgroundView: some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
            .onTapGesture {
                // Don't dismiss on background tap - user must choose
            }
    }
    
    @ViewBuilder
    private var alertContentView: some View {
        VStack(spacing: 0) {
            headerSection
            dropdownSection
            donateButton
            donateLaterButton
        }
        .frame(maxWidth: 320)
        .background(alertBackground)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        Text("Support Our Cause")
            .font(.canela(size: 24, weight: .bold))
            .foregroundColor(AppColors.customTextColor)
            .padding(.top, 24)
            .padding(.bottom, 8)
        
        Text("Select an amount to donate")
            .font(.canela(size: 14, weight: .regular))
            .foregroundColor(AppColors.customPlaceholderText)
            .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var dropdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Donation Amount")
                .font(.canela(size: 14, weight: .medium))
                .foregroundColor(AppColors.customTextColor)
            
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    // Dropdown button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showDropdown.toggle()
                        }
                    }) {
                        dropdownLabel
                    }
                    .zIndex(showDropdown ? 2 : 1)
                    
                    // Dropdown menu list
                    if showDropdown {
                        dropdownMenuList
                            .zIndex(3)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            
            if showValidationError {
                validationErrorText
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var dropdownMenuList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if availableProducts.isEmpty {
                    Text(isLoading ? "Loading options…" : "No donation options")
                        .font(.canela(size: 16, weight: .medium))
                        .foregroundColor(AppColors.customPlaceholderText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                } else {
                    ForEach(availableProducts, id: \.productId) { product in
                        Button(action: {
                            selectedProductId = product.productId
                            showValidationError = false
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showDropdown = false
                            }
                        }) {
                            HStack {
                                Text(product.displayName)
                                    .font(.canela(size: 16, weight: .medium))
                                    .foregroundColor(AppColors.customTextColor)
                                
                                Spacer()
                                
                                if selectedProductId == product.productId {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.customButtonColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: selectedProductId == product.productId ? 8 : 0)
                                .fill(selectedProductId == product.productId ? AppColors.customButtonColor.opacity(0.1) : Color.clear)
                        )
                        
                        if product.productId != availableProducts.last?.productId {
                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 240) // ~4 options visible, then scroll
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    @ViewBuilder
    private var dropdownLabel: some View {
        HStack {
            Text(selectedAmountText)
                .font(.canela(size: 16, weight: .medium))
                .foregroundColor(selectedProductId == nil ? AppColors.customPlaceholderText : AppColors.customTextColor)
            
            Spacer()
            
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.customPlaceholderText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(dropdownBackground)
        .contentShape(Rectangle()) // Ensure entire area is tappable
    }
    
    private var selectedAmountText: String {
        if let productId = selectedProductId,
           let product = availableProducts.first(where: { $0.productId == productId }) {
            return product.displayName
        }
        return "Select amount"
    }
    
    @ViewBuilder
    private var dropdownBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.1))
            .overlay(
                Group {
                    if showValidationError {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.8), lineWidth: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                    }
                }
            )
    }
    
    @ViewBuilder
    private var validationErrorText: some View {
        Text("Please select a donation amount")
            .font(.canela(size: 12, weight: .regular))
            .foregroundColor(.red.opacity(0.9))
            .padding(.top, 4)
    }
    
    @ViewBuilder
    private var donateButton: some View {
        Button(action: {
            handleDonate()
        }) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Text("Donate")
                        .font(.canela(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(donateButtonBackground)
        }
        .disabled(isProcessing)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var donateButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isProcessing ? AppColors.customButtonColor.opacity(0.6) : AppColors.customButtonColor)
    }
    
    @ViewBuilder
    private var donateLaterButton: some View {
        Button(action: {
            onDonateLater()
            isPresented = false
        }) {
            Text("Donate Later")
                .font(.canela(size: 16, weight: .medium))
                .foregroundColor(AppColors.customPlaceholderText)
        }
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var alertBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient.customAppGradient, lineWidth: 2)
            )
            .shadow(color: AppColors.customButtonColor.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private func handleDonate() {
        guard let productId = selectedProductId else {
            showValidationError = true
            return
        }
        
        isProcessing = true
        Task {
            await onDonate(productId)
            isProcessing = false
            isPresented = false
        }
    }
    
    private func loadDonationProducts() async {
        isLoading = true
        
        // Fetch donation packages - search all offerings (avoids ambiguity when multiple offerings exist)
        let packages = await RevenueCatService.shared.fetchDonationProductPackages(offeringIdentifier: nil)
        
        let products: [DonationProduct] = packages.map { package in
            let productId = package.storeProduct.productIdentifier
            let amount = extractAmount(from: productId)
            return DonationProduct(
                productId: productId,
                displayName: "$\(amount) - \(amount) meals",
                amount: amount,
                package: package
            )
        }
        
        self.availableProducts = products
        isLoading = false
        
        print("📦 [DONATION_ALERT] Loaded \(products.count) donation products")
    }
    
    private func extractAmount(from productId: String) -> Int {
        // Prefer explicit mapping for known donation product IDs to avoid any parsing surprises.
        if productId.hasSuffix(".100") { return 100 }
        if productId.hasSuffix(".500") { return 500 }
        if productId.hasSuffix(".1000") { return 1000 }
        if productId.hasSuffix(".2000") { return 2000 }
        if productId.hasSuffix(".5000") { return 5000 }
        if productId.hasSuffix(".10000") { return 10000 }
        
        // Fallback: Extract trailing numeric component (e.g. "com.ramadanpro.donation.250")
        let components = productId.components(separatedBy: ".")
        if let lastComponent = components.last, let amount = Int(lastComponent) {
            return amount
        }
        return 0
    }
}

struct DonationProduct {
    let productId: String
    let displayName: String
    let amount: Int
    let package: Package
}
