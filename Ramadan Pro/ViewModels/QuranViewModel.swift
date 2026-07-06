//
//  QuranViewModel.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth

/// ViewModel for managing Quran data and reading state
@MainActor
class QuranViewModel: ObservableObject {
    static let shared = QuranViewModel()
    
    // MARK: - Published Properties
    
    @Published var surahs: [Surah] = []
    @Published var currentSurah: Surah?
    @Published var currentAyahs: [Ayah] = []
    @Published var lastRead: LastRead?
    @Published var bookmarks: [Bookmark] = []
    
    @Published var searchQuery: String = ""
    @Published var filteredSurahs: [Surah] = [] // Will be populated from surahs
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Pagination state
    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1
    @Published var hasNextPage: Bool = false
    @Published var hasPreviousPage: Bool = false
    
    // Reading preferences
    @Published var fontSize: CGFloat = 24
    @Published var showTranslation: Bool = true
    @Published var isNightMode: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = QuranAPIService.shared
    private let bookmarkService = FirebaseBookmarkService.shared
    
    // MARK: - Initialization
    
    private init() {
        loadLastRead()
        loadBookmarks()
        
        // Sync bookmarks from Firebase if user is authenticated
        Task {
            await syncBookmarksFromFirebase()
        }
        
        // Observe search query changes to filter surahs
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.filterSurahs(query: query)
            }
            .store(in: &cancellables)
        
        // Observe surahs changes to update filtered list
        $surahs
            .sink { [weak self] surahs in
                self?.filterSurahs(query: self?.searchQuery ?? "")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Search Methods
    
    /// Filter surahs based on search query
    private func filterSurahs(query: String) {
        if query.isEmpty {
            filteredSurahs = surahs
        } else {
            let lowercaseQuery = query.lowercased()
            filteredSurahs = surahs.filter { surah in
                surah.englishName.lowercased().contains(lowercaseQuery) ||
                surah.arabicName.contains(query) ||
                surah.transliteration.lowercased().contains(lowercaseQuery) ||
                String(surah.number).contains(lowercaseQuery)
            }
        }
        print("🔍 QuranViewModel: Filtered \(filteredSurahs.count) surahs for query: '\(query)'")
    }
    
    
    // MARK: - Public Methods
    
    /// Load all surahs from API
    func loadSurahs() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedSurahs = try await apiService.fetchAllSurahs()
            self.surahs = fetchedSurahs
            filterSurahs(query: searchQuery) // Filter after loading
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Load surah by number or name, optionally with target ayah number for bookmark
    func loadSurah(number: Int? = nil, name: String? = nil, targetAyahNumber: Int? = nil) async {
        // Set loading state immediately - clear previous data and errors
        isLoading = true
        errorMessage = nil
        currentAyahs = [] // Clear previous ayahs
        
        do {
            // Use number if provided, otherwise find by name
            var surahNumber: Int?
            if let number = number {
                surahNumber = number
            } else if let name = name {
                // If surahs list is empty, load it first
                if surahs.isEmpty {
                    await loadSurahs()
                }
                // Find surah number by name
                surahNumber = surahs.first(where: { $0.englishName.lowercased() == name.lowercased() })?.number
                
                // If still not found, try to extract number from name (e.g., "Al-Fatihah" -> 1)
                // Or try fetching by name directly from API
                if surahNumber == nil {
                    // Try to match partial names
                    surahNumber = surahs.first(where: {
                        $0.englishName.lowercased().contains(name.lowercased()) ||
                        name.lowercased().contains($0.englishName.lowercased())
                    })?.number
                }
            }
            
            guard let num = surahNumber else {
                errorMessage = "Surah '\(name ?? "unknown")' not found"
                isLoading = false
                print("❌ QuranViewModel: Could not find surah '\(name ?? "unknown")' in \(surahs.count) loaded surahs")
                return
            }
            
            print("📖 QuranViewModel: Loading surah number \(num) (\(name ?? ""))")
            
            // Start by loading first page
            currentPage = 1
            let (surah, ayahs, pagination) = try await apiService.fetchSurahWithVerses(surahNumber: num, page: currentPage)
            self.currentSurah = surah
            self.currentAyahs = ayahs
            
            // Update pagination state
            if let pagination = pagination {
                self.currentPage = pagination.currentPage ?? 1
                self.totalPages = pagination.totalPages ?? 1
                self.hasNextPage = pagination.nextPage != nil
                self.hasPreviousPage = (pagination.currentPage ?? 1) > 1
            } else {
                // Default to no pagination if not provided
                self.totalPages = 1
                self.hasNextPage = false
                self.hasPreviousPage = false
            }
            
            // If target ayah is specified and not in first page, try to find the correct page
            if let targetAyah = targetAyahNumber, !ayahs.contains(where: { $0.number == targetAyah }) {
                print("🔍 QuranViewModel: Searching for target ayah \(targetAyah) (not on page \(currentPage))")
                
                // Estimate which page might contain this ayah (assuming ~10 ayahs per page)
                let estimatedPage = max(1, min((targetAyah / 10) + 1, totalPages))
                var foundPage = false
                
                // Try pages systematically: estimated page first, then nearby pages, then all pages
                var pagesToTry: [Int] = [estimatedPage]
                
                // Add pages around the estimated page
                for offset in 1...3 {
                    if estimatedPage - offset >= 1 {
                        pagesToTry.append(estimatedPage - offset)
                    }
                    if estimatedPage + offset <= totalPages {
                        pagesToTry.append(estimatedPage + offset)
                    }
                }
                
                // Remove duplicates and sort
                pagesToTry = Array(Set(pagesToTry)).sorted()
                
                // Try each page
                for tryPage in pagesToTry {
                    guard tryPage >= 1 && tryPage <= totalPages else { continue }
                    
                    print("🔍 QuranViewModel: Checking page \(tryPage) for ayah \(targetAyah)...")
                    let (_, testAyahs, _) = try await apiService.fetchSurahWithVerses(surahNumber: num, page: tryPage)
                    
                    if testAyahs.contains(where: { $0.number == targetAyah }) {
                        // Found it! Update to this page
                        self.currentAyahs = testAyahs
                        self.currentPage = tryPage
                        self.hasPreviousPage = tryPage > 1
                        self.hasNextPage = tryPage < totalPages
                        foundPage = true
                        print("✅ QuranViewModel: Found target ayah \(targetAyah) on page \(tryPage)")
                        break
                    }
                }
                
                // If still not found, try all remaining pages (brute force as last resort)
                if !foundPage {
                    print("⚠️ QuranViewModel: Target ayah not found in estimated pages, trying all pages...")
                    for tryPage in 1...totalPages {
                        guard !pagesToTry.contains(tryPage) else { continue }
                        
                        let (_, testAyahs, _) = try await apiService.fetchSurahWithVerses(surahNumber: num, page: tryPage)
                        if testAyahs.contains(where: { $0.number == targetAyah }) {
                            self.currentAyahs = testAyahs
                            self.currentPage = tryPage
                            self.hasPreviousPage = tryPage > 1
                            self.hasNextPage = tryPage < totalPages
                            foundPage = true
                            print("✅ QuranViewModel: Found target ayah \(targetAyah) on page \(tryPage)")
                            break
                        }
                    }
                }
                
                if !foundPage {
                    print("⚠️ QuranViewModel: Target ayah \(targetAyah) not found in any page, staying on page \(currentPage)")
                    // Reload first page since we might have loaded other pages
                    let (_, firstPageAyahs, _) = try await apiService.fetchSurahWithVerses(surahNumber: num, page: 1)
                    self.currentAyahs = firstPageAyahs
                    self.currentPage = 1
                }
            }
            
            print("✅ QuranViewModel: Loaded \(ayahs.count) ayahs for surah \(num) (page \(currentPage)/\(totalPages))")
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            print("❌ QuranViewModel: Error loading surah: \(error.localizedDescription)")
        }
    }
    
    /// Load ayahs by Quran page number (like page 15 of the Quran)
    func loadQuranPage(_ pageNumber: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let ayahs = try await apiService.fetchVersesByPage(pageNumber: pageNumber)
            self.currentAyahs = ayahs
            // Reset pagination for Quran page navigation
            currentPage = 1
            totalPages = 1
            hasNextPage = false
            hasPreviousPage = false
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Load next page of verses for current surah (pagination within surah)
    func loadNextSurahPage() async {
        guard let currentSurah = currentSurah, hasNextPage else { return }
        
        isLoading = true
        errorMessage = nil
        currentAyahs = [] // Clear previous verses to show only current page
        
        do {
            let nextPage = currentPage + 1
            let (_, ayahs, pagination) = try await apiService.fetchSurahWithVerses(surahNumber: currentSurah.number, page: nextPage)
            self.currentAyahs = ayahs // Replace with new verses (don't append)
            
            // Update pagination state
            if let pagination = pagination {
                self.currentPage = pagination.currentPage ?? nextPage
                self.totalPages = pagination.totalPages ?? totalPages
                self.hasNextPage = pagination.nextPage != nil
                self.hasPreviousPage = true
            }
            
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Load specific page of verses for current surah (pagination within surah)
    func loadSurahPage(_ page: Int) async {
        guard let currentSurah = currentSurah, page >= 1, page <= totalPages else { return }
        
        isLoading = true
        errorMessage = nil
        currentAyahs = [] // Clear previous verses
        
        do {
            let (_, ayahs, pagination) = try await apiService.fetchSurahWithVerses(surahNumber: currentSurah.number, page: page)
            self.currentAyahs = ayahs
            
            // Update pagination state
            if let pagination = pagination {
                self.currentPage = pagination.currentPage ?? page
                self.totalPages = pagination.totalPages ?? totalPages
                self.hasNextPage = pagination.nextPage != nil
                self.hasPreviousPage = page > 1
            }
            
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Load ayahs by juz number
    func loadJuz(_ juzNumber: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let ayahs = try await apiService.fetchVersesByJuz(juzNumber: juzNumber)
            self.currentAyahs = ayahs
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Save last read position
    func saveLastRead(surahNumber: Int, surahName: String, ayahNumber: Int, pageNumber: Int? = nil, juzNumber: Int? = nil) {
        let lastRead = LastRead(
            surahNumber: surahNumber,
            surahName: surahName,
            ayahNumber: ayahNumber,
            pageNumber: pageNumber,
            juzNumber: juzNumber
        )
        lastRead.save()
        self.lastRead = lastRead
        
        // TODO: Sync with backend
        // Task {
        //     await apiService.saveLastRead(lastRead)
        // }
    }
    
    /// Load last read position from local storage
    func loadLastRead() {
        self.lastRead = LastRead.load()
    }
    
    /// Toggle bookmark for an ayah (only one bookmark per surah)
    func toggleBookmark(surahNumber: Int, ayahNumber: Int) {
        // Check if this surah already has a bookmark
        if let existingIndex = bookmarks.firstIndex(where: { $0.surahNumber == surahNumber }) {
            // Check if it's the same ayah - if so, remove it
            if bookmarks[existingIndex].ayahNumber == ayahNumber {
                // Remove bookmark
                let removedBookmark = bookmarks.remove(at: existingIndex)
                saveBookmarks()
                
                // Sync with Firebase
                Task {
                    await syncBookmarkToFirebase(bookmark: removedBookmark, shouldDelete: true)
                }
            } else {
                // Replace existing bookmark with new ayah
                let oldBookmark = bookmarks[existingIndex]
                bookmarks[existingIndex] = Bookmark(surahNumber: surahNumber, ayahNumber: ayahNumber)
                saveBookmarks()
                
                // Sync with Firebase
                Task {
                    // Delete old bookmark
                    await syncBookmarkToFirebase(bookmark: oldBookmark, shouldDelete: true)
                    // Add new bookmark
                    await syncBookmarkToFirebase(bookmark: bookmarks[existingIndex], shouldDelete: false)
                }
            }
        } else {
            // Add new bookmark
            let bookmark = Bookmark(surahNumber: surahNumber, ayahNumber: ayahNumber)
            bookmarks.append(bookmark)
            saveBookmarks()
            
            // Sync with Firebase
            Task {
                await syncBookmarkToFirebase(bookmark: bookmark, shouldDelete: false)
            }
        }
    }
    
    /// Check if an ayah is bookmarked
    func isBookmarked(surahNumber: Int, ayahNumber: Int) -> Bool {
        return bookmarks.contains { $0.surahNumber == surahNumber && $0.ayahNumber == ayahNumber }
    }
    
    /// Get bookmark for a surah (returns nil if no bookmark exists for that surah)
    func getBookmark(for surahNumber: Int) -> Bookmark? {
        return bookmarks.first { $0.surahNumber == surahNumber }
    }
    
    /// Check if a surah has a bookmark (any ayah)
    func hasBookmark(for surahNumber: Int) -> Bool {
        return bookmarks.contains { $0.surahNumber == surahNumber }
    }
    
    /// Load bookmarks from local storage
    func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: "quran_bookmarks"),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            self.bookmarks = decoded
            print("📖 QuranViewModel: Loaded \(bookmarks.count) bookmarks from local storage")
        }
    }
    
    /// Save bookmarks to local storage
    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: "quran_bookmarks")
            print("💾 QuranViewModel: Saved \(bookmarks.count) bookmarks to local storage")
        }
    }
    
    // MARK: - Firebase Sync Methods
    
    /// Sync bookmarks with Firebase (fetch from server)
    func syncBookmarksFromFirebase() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ QuranViewModel: No authenticated user, skipping Firebase bookmark sync")
            return
        }
        
        do {
            print("📡 QuranViewModel: Syncing bookmarks from Firebase...")
            let firebaseBookmarks = try await bookmarkService.fetchBookmarks(userId: userId)
            self.bookmarks = firebaseBookmarks
            saveBookmarks() // Save to local storage as backup
            print("✅ QuranViewModel: Synced \(firebaseBookmarks.count) bookmarks from Firebase")
        } catch {
            print("❌ QuranViewModel: Error syncing bookmarks from Firebase: \(error.localizedDescription)")
            // Continue with local bookmarks if sync fails
        }
    }
    
    /// Sync a single bookmark to Firebase (add or delete)
    private func syncBookmarkToFirebase(bookmark: Bookmark, shouldDelete: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ QuranViewModel: No authenticated user, skipping Firebase bookmark sync")
            return
        }
        
        do {
            if shouldDelete {
                try await bookmarkService.deleteBookmark(bookmarkId: bookmark.id.uuidString, userId: userId)
                print("✅ QuranViewModel: Deleted bookmark from Firebase")
            } else {
                try await bookmarkService.saveBookmark(bookmark, userId: userId)
                print("✅ QuranViewModel: Saved bookmark to Firebase")
            }
        } catch {
            print("❌ QuranViewModel: Error syncing bookmark to Firebase: \(error.localizedDescription)")
        }
    }
    
    /// Sync all bookmarks to Firebase (useful for initial sync or manual refresh)
    func syncAllBookmarksToFirebase() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ QuranViewModel: No authenticated user, skipping Firebase bookmark sync")
            return
        }
        
        do {
            print("📡 QuranViewModel: Syncing all \(bookmarks.count) bookmarks to Firebase...")
            try await bookmarkService.saveBookmarks(bookmarks, userId: userId)
            print("✅ QuranViewModel: Successfully synced all bookmarks to Firebase")
        } catch {
            print("❌ QuranViewModel: Error syncing all bookmarks to Firebase: \(error.localizedDescription)")
        }
    }
    
    /// Clear local Quran data (bookmarks, last read). Call on logout.
    func clearLocalData() {
        bookmarks = []
        lastRead = nil
        UserDefaults.standard.removeObject(forKey: "quran_bookmarks")
        UserDefaults.standard.removeObject(forKey: "last_read_quran")
    }

    /// Change font size (cycles through sizes)
    func changeFontSize() {
        switch fontSize {
        case 20:
            fontSize = 24
        case 24:
            fontSize = 28
        case 28:
            fontSize = 20
        default:
            fontSize = 24
        }
    }
    
    /// Increase font size
    func increaseFontSize() {
        switch fontSize {
        case 20:
            fontSize = 24
        case 24:
            fontSize = 28
        case 28:
            // Already at max, keep at 28
            break
        default:
            fontSize = 24
        }
    }
    
    /// Decrease font size
    func decreaseFontSize() {
        switch fontSize {
        case 20:
            // Already at min, keep at 20
            break
        case 24:
            fontSize = 20
        case 28:
            fontSize = 24
        default:
            fontSize = 20
        }
    }
    
}
