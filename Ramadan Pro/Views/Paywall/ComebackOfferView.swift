import SwiftUI

/// Full-screen "come back" offer: 33% off the first year with App Store offer code COMEBACK33.
/// Shown when the email link opens the app, or when a returning account signs in again.
struct ComebackOfferView: View {
    @ObservedObject private var offer = ComebackOfferService.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppColors.slBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 44))
                        .foregroundColor(AppColors.slGreen)
                        .padding(.top, 56)

                    Text("Fajr is calling you")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)

                    Text("Every dawn the adhan says: \u{201C}Prayer is better than sleep.\u{201D} You came back because your heart wants to answer it.")
                        .font(.system(size: 17))
                        .foregroundColor(AppColors.slTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\u{201C}The two rak'ahs of Fajr are better than this world and everything in it.\u{201D}")
                            .font(.system(size: 17).italic())
                            .foregroundColor(AppColors.slTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Prophet Muhammad \u{FDFA}, Sahih Muslim 725")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.slTextSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.slGreen.opacity(0.08))
                    .overlay(Rectangle().fill(AppColors.slGreen).frame(width: 4), alignment: .leading)
                    .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("33% off your first year")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppColors.slGreen)
                        Text("A one-time gift for coming back. After the first year it renews at the normal yearly price. Cancel anytime in Settings.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.slTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)

                    Button {
                        offer.redeem()
                    } label: {
                        Text("Claim my 33% off")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.slGreen)
                            .cornerRadius(14)
                    }
                    .padding(.top, 8)

                    Text("The App Store opens with code \(ComebackOfferService.offerCode) already filled in. Tap Redeem to confirm.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("May Allah make us among those who never miss Fajr. Ameen.")
                        .font(.system(size: 15).italic())
                        .foregroundColor(AppColors.slTextSecondary)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }

            Button {
                offer.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.slTextSecondary)
                    .padding(12)
            }
            .accessibilityLabel("Close")
            .padding(.top, 8)
            .padding(.trailing, 12)
        }
        .onAppear { offer.markShown() }
    }
}
