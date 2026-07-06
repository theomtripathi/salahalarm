//
//  Quran.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation

/// Represents a single verse (Ayah) in the Quran
struct Ayah: Identifiable, Codable, Hashable {
    let id: UUID
    let number: Int
    let arabic: String
    let translation: String
    let surahNumber: Int
    let juzNumber: Int?
    let pageNumber: Int?
    let isBookmarked: Bool
    
    init(id: UUID = UUID(),
         number: Int,
         arabic: String,
         translation: String,
         surahNumber: Int,
         juzNumber: Int? = nil,
         pageNumber: Int? = nil,
         isBookmarked: Bool = false) {
        self.id = id
        self.number = number
        self.arabic = arabic
        self.translation = translation
        self.surahNumber = surahNumber
        self.juzNumber = juzNumber
        self.pageNumber = pageNumber
        self.isBookmarked = isBookmarked
    }
}

/// Represents a chapter (Surah) in the Quran
struct Surah: Identifiable, Codable, Hashable {
    let id: UUID
    let number: Int
    let arabicName: String
    let englishName: String
    let transliteration: String
    let ayahCount: Int
    let revelationType: RevelationType
    let ayahs: [Ayah]?
    
    init(id: UUID = UUID(),
         number: Int,
         arabicName: String,
         englishName: String,
         transliteration: String,
         ayahCount: Int,
         revelationType: RevelationType = .meccan,
         ayahs: [Ayah]? = nil) {
        self.id = id
        self.number = number
        self.arabicName = arabicName
        self.englishName = englishName
        self.transliteration = transliteration
        self.ayahCount = ayahCount
        self.revelationType = revelationType
        self.ayahs = ayahs
    }
}

/// Revelation type of a Surah
enum RevelationType: String, Codable {
    case meccan = "Meccan"
    case medinan = "Medinan"
}

/// Represents a Juz (part) of the Quran
struct Juz: Identifiable, Codable, Hashable {
    let id: UUID
    let number: Int
    let startSurah: Int
    let startAyah: Int
    let endSurah: Int
    let endAyah: Int
    
    init(id: UUID = UUID(),
         number: Int,
         startSurah: Int,
         startAyah: Int,
         endSurah: Int,
         endAyah: Int) {
        self.id = id
        self.number = number
        self.startSurah = startSurah
        self.startAyah = startAyah
        self.endSurah = endSurah
        self.endAyah = endAyah
    }
}

/// Represents a page in the Quran (Mushaf)
struct Page: Identifiable, Codable, Hashable {
    let id: UUID
    let number: Int
    let ayahs: [Ayah]
    
    init(id: UUID = UUID(), number: Int, ayahs: [Ayah]) {
        self.id = id
        self.number = number
        self.ayahs = ayahs
    }
}

/// Represents the last read position in the Quran
struct LastRead: Codable {
    let surahNumber: Int
    let surahName: String
    let ayahNumber: Int
    let timestamp: Date
    let pageNumber: Int?
    let juzNumber: Int?
    
    init(surahNumber: Int,
         surahName: String,
         ayahNumber: Int,
         timestamp: Date = Date(),
         pageNumber: Int? = nil,
         juzNumber: Int? = nil) {
        self.surahNumber = surahNumber
        self.surahName = surahName
        self.ayahNumber = ayahNumber
        self.timestamp = timestamp
        self.pageNumber = pageNumber
        self.juzNumber = juzNumber
    }
    
    /// Save to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "last_read_quran")
        }
    }
    
    /// Load from UserDefaults
    static func load() -> LastRead? {
        guard let data = UserDefaults.standard.data(forKey: "last_read_quran"),
              let lastRead = try? JSONDecoder().decode(LastRead.self, from: data) else {
            return nil
        }
        return lastRead
    }
}

/// Bookmark for a specific Ayah
struct Bookmark: Identifiable, Codable {
    let id: UUID
    let surahNumber: Int
    let ayahNumber: Int
    let timestamp: Date
    let note: String?
    
    init(id: UUID = UUID(),
         surahNumber: Int,
         ayahNumber: Int,
         timestamp: Date = Date(),
         note: String? = nil) {
        self.id = id
        self.surahNumber = surahNumber
        self.ayahNumber = ayahNumber
        self.timestamp = timestamp
        self.note = note
    }
}

/// Response model for API calls (can be extended with backend response structure)
struct QuranAPIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
    let error: String?
}

/// Pagination info for API responses
struct PaginationInfo: Codable {
    let page: Int
    let perPage: Int
    let totalPages: Int
    let totalItems: Int
}
