//
//  QuranReadingView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

struct QuranReadingView: View {
    let surah: String?
    let juz: Int?
    let page: Int?
    
    @ObservedObject private var viewModel = QuranViewModel.shared
    
    var body: some View {
        GeometryReader { backgroundGeometry in
            // Background layer - same as onboarding
            ZStack {
                Image("background_image")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: backgroundGeometry.size.width, height: backgroundGeometry.size.height)
                
                // Dark overlay for readability
                Color.black.opacity(0.6)
            }
            .ignoresSafeArea()
            .frame(width: backgroundGeometry.size.width, height: backgroundGeometry.size.height)
            
            GeometryReader { contentGeometry in
                VStack(spacing: 0) {
                    // Top Bar
                    topBar
                    
                    // Ayah cards
                    ScrollView {
                        VStack(spacing: 32) {
                            if viewModel.isLoading {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                        .tint(AppColors.customButtonColor)
                                    Text(L10n.text("Loading verses…"))
                                        .font(.canela(size: 14, weight: .regular))
                                        .foregroundColor(AppColors.customPlaceholderText)
                                }
                                .padding(.top, 100)
                            } else if let errorMessage = viewModel.errorMessage {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 32))
                                        .foregroundColor(AppColors.customPlaceholderText)
                                    Text(errorMessage)
                                        .font(.canela(size: 14, weight: .regular))
                                        .foregroundColor(AppColors.customPlaceholderText)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                .padding(.top, 100)
                            } else if viewModel.currentAyahs.isEmpty {
                                Text(L10n.text("No verses available"))
                                    .font(.canela(size: 16, weight: .medium))
                                    .foregroundColor(AppColors.customPlaceholderText)
                                    .padding(.top, 100)
                            } else {
                                ForEach(viewModel.currentAyahs) { ayah in
                                    ayahCard(ayah: ayah)
                                        .padding(.horizontal, 32)
                                        .padding(.top, 24)
                                }
                                
                                
                            }
                        }
                        .padding(.bottom, 100)
                    }
                    
                    // Bottom Controls
                    bottomControls
                }
                .frame(width: contentGeometry.size.width, height: contentGeometry.size.height)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Reset state when view appears - clear previous errors and set loading
            // This ensures loading shows immediately when navigating to this view
            if viewModel.currentAyahs.isEmpty {
                viewModel.errorMessage = nil
                viewModel.isLoading = true
            }
        }
        .task {
            // Ensure surahs are loaded first
            if viewModel.surahs.isEmpty {
                await viewModel.loadSurahs()
            }
            
            // Load data based on parameters
            if let surahName = surah {
                // Check if there's a bookmark for this surah
                let surahNumber = viewModel.surahs.first(where: { $0.englishName.lowercased() == surahName.lowercased() })?.number
                let bookmark = surahNumber != nil ? viewModel.getBookmark(for: surahNumber!) : nil
                
                // Use bookmark ayah if available, otherwise use last read ayah if surah matches
                let targetAyah: Int?
                if let bookmarkAyah = bookmark?.ayahNumber {
                    targetAyah = bookmarkAyah
                } else if let lastRead = viewModel.lastRead,
                          lastRead.surahName.lowercased() == surahName.lowercased() {
                    targetAyah = lastRead.ayahNumber
                } else {
                    targetAyah = nil
                }
                
                // Load surah with target ayah (bookmark or last read)
                await viewModel.loadSurah(name: surahName, targetAyahNumber: targetAyah)
                
                // Save last read position
                if let currentSurah = viewModel.currentSurah {
                    viewModel.saveLastRead(
                        surahNumber: currentSurah.number,
                        surahName: currentSurah.englishName,
                        ayahNumber: bookmark?.ayahNumber ?? viewModel.currentAyahs.first?.number ?? 1
                    )
                }
            } else if let juzNum = juz {
                await viewModel.loadJuz(juzNum)
            } else if let pageNum = page {
                await viewModel.loadQuranPage(pageNum)
            }
        }
        .onDisappear {
            // Save last read position when leaving the view
            if let currentSurah = viewModel.currentSurah,
               let firstAyah = viewModel.currentAyahs.first {
                viewModel.saveLastRead(
                    surahNumber: currentSurah.number,
                    surahName: currentSurah.englishName,
                    ayahNumber: firstAyah.number,
                    pageNumber: firstAyah.pageNumber,
                    juzNumber: firstAyah.juzNumber
                )
            }
        }
    }
    
    // MARK: - Top Bar
    
    @ViewBuilder
    private var topBar: some View {
        HStack {
            Spacer()
            
            Text(viewModel.currentSurah?.englishName ?? surah ?? L10n.text("Quran"))
                .font(.canela(size: 18, weight: .semibold))
                .foregroundColor(AppColors.customTextColor)
            
            Spacer()
            
            // Bookmark icon (shows if any ayah in current surah is bookmarked)
//            if let currentSurah = viewModel.currentSurah {
//                Button(action: {
//                    // Toggle bookmark for first ayah (or could implement surah-level bookmark)
//                }) {
//                    Image(systemName: "bookmark")
//                        .font(.system(size: 20))
//                        .foregroundColor(AppColors.accent)
//                }
//            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 32)
        .padding(.bottom, 20)
    }
    
    // MARK: - Ayah Card
    
    @ViewBuilder
    private func ayahCard(ayah: Ayah) -> some View {
        VStack(spacing: 16) {
            // Arabic text - large, center aligned
            Text(ayah.arabic)
                .font(.system(size: viewModel.fontSize))
                .foregroundColor(AppColors.customTextColor)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
            
            // Translation - smaller, gray
            if viewModel.showTranslation {
                Text(ayah.translation)
                    .font(.canela(size: 14, weight: .regular))
                    .foregroundColor(AppColors.customPlaceholderText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Ayah number with font size controls
            HStack(spacing: 16) {
                // Decrease font size button (aA-)
                Button(action: {
                    viewModel.decreaseFontSize()
                }) {
                    Text("aA-")
                        .font(.canela(size: 14, weight: .medium))
                        .foregroundColor(AppColors.customButtonColor)
                }
                
                Spacer()
                
                // Ayah number in gold circle (centered)
                ZStack {
                    Circle()
                        .fill(AppColors.customButtonColor)
                        .frame(width: 32, height: 32)
                    
                    Text("\(ayah.number)")
                        .font(.canela(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // Increase font size button (aA+)
                Button(action: {
                    viewModel.increaseFontSize()
                }) {
                    Text("aA+")
                        .font(.canela(size: 14, weight: .medium))
                        .foregroundColor(AppColors.customButtonColor)
                }
            }
//            
//            // Actions: Bookmark, Share, Audio
//            HStack(spacing: 24) {
//                // Bookmark
//                Button(action: {
//                    viewModel.toggleBookmark(surahNumber: ayah.surahNumber, ayahNumber: ayah.number)
//                }) {
//                    Image(systemName: viewModel.isBookmarked(surahNumber: ayah.surahNumber, ayahNumber: ayah.number) ? "bookmark.fill" : "bookmark")
//                        .font(.system(size: 18))
//                        .foregroundColor(AppColors.accent)
//                }
//                
//                // Share
//                Button(action: {
//                    // TODO: Implement share
//                }) {
//                    Image(systemName: "square.and.arrow.up")
//                        .font(.system(size: 18))
//                        .foregroundColor(AppColors.accent)
//                }
//                
//                // Audio play
//                Button(action: {
//                    // TODO: Implement audio
//                }) {
//                    Image(systemName: "play.circle.fill")
//                        .font(.system(size: 24))
//                        .foregroundColor(AppColors.accent)
//                }
//            }
//            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                )
                .shadow(color: AppColors.customButtonColor.opacity(0.2), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Pagination Controls
    
    @ViewBuilder
    private var paginationControls: some View {
        HStack(spacing: 16) {
            // Previous button - active if current page > 1
            Button(action: {
                Task {
                    await viewModel.loadSurahPage(viewModel.currentPage - 1)
                }
            }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor((viewModel.currentPage > 1) ? AppColors.customButtonColor : AppColors.customPlaceholderText.opacity(0.3))
            }
            .disabled(viewModel.currentPage <= 1)
            
            Spacer()
            
            // Page indicator
            Text(L10n.format("%d of %d", viewModel.currentPage, viewModel.totalPages))
                .font(.canela(size: 14, weight: .medium))
                .foregroundColor(AppColors.customTextColor)
            
            Spacer()
            
            // Next button
            Button(action: {
                Task {
                    await viewModel.loadNextSurahPage()
                }
            }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.hasNextPage ? AppColors.customButtonColor : AppColors.customPlaceholderText.opacity(0.3))
            }
            .disabled(!viewModel.hasNextPage)
            
            // Bookmark button - bookmark the current page
            if let firstAyah = viewModel.currentAyahs.first,
               let currentSurah = viewModel.currentSurah {
                Button(action: {
                    viewModel.toggleBookmark(surahNumber: currentSurah.number, ayahNumber: firstAyah.number)
                }) {
                    Image(systemName: viewModel.isBookmarked(surahNumber: currentSurah.number, ayahNumber: firstAyah.number) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(viewModel.isBookmarked(surahNumber: currentSurah.number, ayahNumber: firstAyah.number) ? AppColors.customButtonColor : AppColors.customPlaceholderText)
                }
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Bottom Controls
    
    @ViewBuilder
    private var bottomControls: some View {
        // Pagination controls (if multiple pages)
        if viewModel.totalPages > 1 {
            paginationControls
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            Rectangle()
                                .fill(LinearGradient.customAppGradient.opacity(0.1))
                        )
                        .shadow(color: AppColors.customButtonColor.opacity(0.2), radius: 8, x: 0, y: -2)
                )
        }
    }
}
