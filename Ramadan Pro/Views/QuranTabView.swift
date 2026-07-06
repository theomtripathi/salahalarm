//
//  QuranTabView.swift
//  Ramadan Pro
//

import SwiftUI

struct QuranTabView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var appState: AppState
    @ObservedObject private var viewModel = QuranViewModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchBar
                lastReadCard
                if !viewModel.bookmarks.isEmpty {
                    bookmarksSection
                }
                surahList
            }
            .padding(20)
        }
        .background(AppColors.slCream.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.surahs.isEmpty {
                await viewModel.loadSurahs()
            }
            await viewModel.syncBookmarksFromFirebase()
        }
        .refreshable {
            await viewModel.loadSurahs()
            await viewModel.syncBookmarksFromFirebase()
        }
        .onAppear {
            viewModel.loadBookmarks()
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image("logo")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quran")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("Read with focus and resume where you left off.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                }
            }
            Spacer()
            Button {
                appState.selectedTab = AppEnums.TabItem.profile.rawValue
            } label: {
                Circle()
                    .fill(AppColors.slGreen.opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(AppColors.slGreen)
                    )
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.slTextSecondary)
            TextField("Search surah", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.slTextSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.slBorderDefault, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var lastReadCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Continue Reading")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.slTextSecondary)
            Text(viewModel.lastRead?.surahName ?? "Al-Fatihah")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
            Text("Ayah \(viewModel.lastRead?.ayahNumber ?? 1)")
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
            SLPrimaryButton(title: "Resume") {
                let targetSurah = viewModel.lastRead?.surahName ?? "Al-Fatihah"
                navigationCoordinator.navigateToQuranRoute(.quranReading(surah: targetSurah, juz: nil, page: nil))
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bookmarks")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.bookmarks, id: \.id) { bookmark in
                        Button {
                            if let surah = viewModel.surahs.first(where: { $0.number == bookmark.surahNumber }) {
                                navigationCoordinator.navigateToQuranRoute(.quranReading(surah: surah.englishName, juz: nil, page: nil))
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(getSurahName(for: bookmark.surahNumber) ?? "Surah \(bookmark.surahNumber)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.slTextPrimary)
                                Text("Ayah \(bookmark.ayahNumber)")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.slTextSecondary)
                            }
                            .padding(14)
                            .frame(width: 140, alignment: .leading)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var surahList: some View {
        let displaySurahs = viewModel.searchQuery.isEmpty ? viewModel.surahs : viewModel.filteredSurahs
        VStack(alignment: .leading, spacing: 12) {
            Text("Surahs")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if displaySurahs.isEmpty {
                Text("No surahs found")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(displaySurahs, id: \.id) { surah in
                        Button {
                            navigationCoordinator.navigateToQuranRoute(.quranReading(surah: surah.englishName, juz: nil, page: nil))
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.slGreen.opacity(0.14))
                                        .frame(width: 44, height: 44)
                                    Text("\(surah.number)")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(AppColors.slGreen)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(surah.arabicName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(AppColors.slTextPrimary)
                                    Text("\(surah.englishName) • \(surah.ayahCount) ayahs")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.slTextSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.slTextSecondary)
                            }
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        }
                    }
                }
            }
        }
    }

    private func getSurahName(for surahNumber: Int) -> String? {
        viewModel.surahs.first(where: { $0.number == surahNumber })?.englishName
    }
}

#Preview {
    QuranTabView()
        .environmentObject(NavigationCoordinator.shared)
        .environmentObject(AppState.shared)
}
