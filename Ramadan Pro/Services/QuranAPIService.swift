//
//  QuranAPIService.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine

/// Service for fetching Quran data from Quran.com API
/// Documentation: https://quran.api-docs.io/
class QuranAPIService {
    static let shared = QuranAPIService()
    
    private let baseURL = "https://api.quran.com/api/v4"
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        // Configure decoder to convert snake_case to camelCase
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    private func cleanHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<sup foot_note=\\d+>.*?</sup>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - API Response Models
    
    struct APIResponse<T: Codable>: Codable {
        let meta: Meta?
        let data: T?
        let chapter: T? // Single chapter endpoint uses 'chapter'
        let chapters: T? // List endpoint uses 'chapters'
        let verses: T? // Verses endpoint uses 'verses'
        let verse: T? // Single verse endpoint uses 'verse'
    }
    
    // Direct response for chapters endpoint (returns {chapters: [...]})
    struct ChaptersResponse: Codable {
        let chapters: [APISurah]
    }
    
    struct Meta: Codable {
        let currentPage: Int?
        let totalPages: Int?
        let totalCount: Int?
    }
    
    struct APISurah: Codable {
        let id: Int
        let revelationPlace: String
        let revelationOrder: Int
        let bismillahPre: Bool
        let nameSimple: String
        let nameComplex: String
        let nameArabic: String
        let versesCount: Int
        let pages: [Int]
        let translatedName: TranslatedName?
    }
    
    struct TranslatedName: Codable {
        let languageName: String
        let name: String
    }
    
    struct APIVerse: Codable {
        let id: Int
        let verseNumber: Int
        let verseKey: String
        let juzNumber: Int
        let hizbNumber: Int
        let rubElHizbNumber: Int
        let rukuNumber: Int
        let manzilNumber: Int
        let sajdahNumber: Int?
        let pageNumber: Int
        let textUthmani: String?
        let textIndopak: String?
        let textSimple: String? // Made optional - may not be in initial response
        let translations: [APITranslation]?
    }
    
    struct APITranslation: Codable {
        let id: Int
        let resourceId: Int?
        let text: String
        let languageName: String
        let languageId: Int? // Made optional - API may not always include this
    }
    
    struct VersesWrapper: Codable {
        let verses: [APIVerse]
    }
    
    // Direct verses response structure: {"verses": [...], "pagination": {...}}
    struct VersesResponse: Codable {
        let verses: [APIVerse]
        let pagination: PaginationInfo?
    }
    
    struct PaginationInfo: Codable {
        let perPage: Int?
        let currentPage: Int?
        let nextPage: Int?
        let totalPages: Int?
        let totalRecords: Int?
    }
    
    // MARK: - Fetch All Surahs
    
    func fetchAllSurahs() async throws -> [Surah] {
        let url = URL(string: "\(baseURL)/chapters")!
        print("📡 QuranAPI: Fetching all surahs from \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ QuranAPI: Invalid HTTP response")
            throw QuranAPIError.invalidResponse
        }
        
        print("📥 QuranAPI: Response status code: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ QuranAPI: HTTP error status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 QuranAPI: Response body: \(responseString.prefix(500))")
            }
            throw QuranAPIError.invalidResponse
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 QuranAPI: Raw response (first 1000 chars): \(String(responseString.prefix(1000)))")
        }
        
        // Try decoding as direct ChaptersResponse first (most common format)
        var apiSurahs: [APISurah]
        if let chaptersResponse = try? decoder.decode(ChaptersResponse.self, from: data) {
            apiSurahs = chaptersResponse.chapters
            print("✅ QuranAPI: Decoded as ChaptersResponse, found \(apiSurahs.count) surahs")
        } else if let apiResponse = try? decoder.decode(APIResponse<[APISurah]>.self, from: data),
                  let surahs = apiResponse.chapters ?? apiResponse.data {
            apiSurahs = surahs
            print("✅ QuranAPI: Decoded as APIResponse, found \(apiSurahs.count) surahs")
        } else {
            print("❌ QuranAPI: Failed to decode surahs response")
            print("❌ QuranAPI: Trying to decode error details...")
            if let errorResponse = try? decoder.decode([String: String].self, from: data) {
                print("❌ QuranAPI: Error response: \(errorResponse)")
            }
            throw QuranAPIError.noData
        }
        
        print("✅ QuranAPI: Successfully fetched \(apiSurahs.count) surahs")
        
        // Convert API models to app models
        return apiSurahs.map { apiSurah in
            let revelationType: RevelationType = apiSurah.revelationPlace.lowercased() == "makkah" ? .meccan : .medinan
            
            return Surah(
                number: apiSurah.id,
                arabicName: apiSurah.nameArabic,
                englishName: apiSurah.nameSimple,
                transliteration: apiSurah.nameComplex,
                ayahCount: apiSurah.versesCount,
                revelationType: revelationType,
                ayahs: nil // Load ayahs separately
            )
        }
    }

    func fetchVerse(surahNumber: Int, ayahNumber: Int) async throws -> Ayah {
        let url = URL(string: "\(baseURL)/verses/by_key/\(surahNumber):\(ayahNumber)?translations=20&translation_fields=text,language_name&fields=text_uthmani,text_simple")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw QuranAPIError.invalidResponse
        }

        let verseResponse = try decoder.decode(APIResponse<APIVerse>.self, from: data)
        guard let apiVerse = verseResponse.verse ?? verseResponse.data else {
            throw QuranAPIError.noData
        }
        let translation = cleanHTML(apiVerse.translations?.first?.text ?? "")
        let arabicText = apiVerse.textUthmani ?? apiVerse.textSimple ?? apiVerse.verseKey

        return Ayah(
            number: apiVerse.verseNumber,
            arabic: arabicText,
            translation: translation,
            surahNumber: surahNumber,
            juzNumber: apiVerse.juzNumber,
            pageNumber: apiVerse.pageNumber
        )
    }
    
    // MARK: - Fetch Surah with Verses
    
    func fetchSurahWithVerses(surahNumber: Int, page: Int = 1, perPage: Int = 10, translationLanguage: String = "en") async throws -> (surah: Surah, ayahs: [Ayah], pagination: PaginationInfo?) {
        print("📡 QuranAPI: Fetching surah \(surahNumber) with verses")
        
        // Fetch surah info
        let surahURL = URL(string: "\(baseURL)/chapters/\(surahNumber)")!
        print("📡 QuranAPI: Fetching surah info from \(surahURL)")
        
        let (surahData, surahResponse) = try await session.data(from: surahURL)
        
        guard let surahHttpResponse = surahResponse as? HTTPURLResponse else {
            print("❌ QuranAPI: Invalid HTTP response for surah info")
            throw QuranAPIError.invalidResponse
        }
        
        print("📥 QuranAPI: Surah info response status: \(surahHttpResponse.statusCode)")
        
        guard (200...299).contains(surahHttpResponse.statusCode) else {
            print("❌ QuranAPI: HTTP error for surah info: \(surahHttpResponse.statusCode)")
            throw QuranAPIError.invalidResponse
        }
        
            let surahAPIResponse = try decoder.decode(APIResponse<APISurah>.self, from: surahData)
        guard let apiSurah = surahAPIResponse.chapter ?? surahAPIResponse.data else {
            print("❌ QuranAPI: No surah data in response")
            throw QuranAPIError.noData
        }
        
        print("✅ QuranAPI: Loaded surah: \(apiSurah.nameSimple) (\(apiSurah.nameArabic))")
        
        // Fetch verses with text and translations (with pagination)
        // translations=20 is Sahih International (English), translation_fields specifies what to include
        let versesURL = URL(string: "\(baseURL)/verses/by_chapter/\(surahNumber)?translations=20&translation_fields=text,language_name&fields=text_uthmani,text_simple&page=\(page)&per_page=\(perPage)")!
        print("📡 QuranAPI: Fetching verses from \(versesURL) (page \(page))")
        
        let (versesData, versesResponse) = try await session.data(from: versesURL)
        
        guard let versesHttpResponse = versesResponse as? HTTPURLResponse else {
            print("❌ QuranAPI: Invalid HTTP response for verses")
            throw QuranAPIError.invalidResponse
        }
        
        print("📥 QuranAPI: Verses response status: \(versesHttpResponse.statusCode)")
        
        guard (200...299).contains(versesHttpResponse.statusCode) else {
            print("❌ QuranAPI: HTTP error for verses: \(versesHttpResponse.statusCode)")
            if let responseString = String(data: versesData, encoding: .utf8) {
                print("📄 QuranAPI: Error response: \(responseString.prefix(500))")
            }
            throw QuranAPIError.invalidResponse
        }
        
        // Print raw response for debugging
        if let responseString = String(data: versesData, encoding: .utf8) {
            print("📄 QuranAPI: Verses response (first 2000 chars): \(String(responseString.prefix(2000)))")
        }
        
        // Try different response formats
        // Format 1: Direct VersesResponse {"verses": [...], "pagination": {...}}
        var apiVerses: [APIVerse]
        var paginationInfo: PaginationInfo?
        do {
            let versesResponse = try decoder.decode(VersesResponse.self, from: versesData)
            apiVerses = versesResponse.verses
            paginationInfo = versesResponse.pagination
            print("✅ QuranAPI: Decoded as VersesResponse, found \(apiVerses.count) verses, page \(paginationInfo?.currentPage ?? 1)/\(paginationInfo?.totalPages ?? 1)")
        } catch let error as DecodingError {
            print("❌ QuranAPI: Failed to decode as VersesResponse: \(error)")
            // Try alternative formats
            if let wrapperResponse = try? decoder.decode(APIResponse<VersesWrapper>.self, from: versesData),
               let verses = wrapperResponse.verses?.verses {
                apiVerses = verses
                print("✅ QuranAPI: Decoded as APIResponse<VersesWrapper>, found \(apiVerses.count) verses")
            } else if let arrayResponse = try? decoder.decode(APIResponse<[APIVerse]>.self, from: versesData),
                      let verses = arrayResponse.verses ?? arrayResponse.data {
                apiVerses = verses
                print("✅ QuranAPI: Decoded as APIResponse<[APIVerse]>, found \(apiVerses.count) verses")
            } else {
                print("❌ QuranAPI: All decoding attempts failed")
                if let responseString = String(data: versesData, encoding: .utf8) {
                    print("📄 QuranAPI: Full response structure: \(responseString.prefix(1000))")
                }
                throw QuranAPIError.decodingError(error)
            }
        } catch {
            print("❌ QuranAPI: Unexpected error during decoding: \(error)")
            throw QuranAPIError.decodingError(error)
        }
        
        // Convert API verses to app models
        let ayahs = apiVerses.map { apiVerse -> Ayah in
            // Clean translation text - remove HTML tags and footnotes
            var translation = apiVerse.translations?.first?.text ?? ""
            translation = cleanTranslationText(translation)
            
            // Handle missing text - use verse key as fallback if no text available
            let arabicText = apiVerse.textUthmani ?? apiVerse.textSimple ?? apiVerse.verseKey
            
            return Ayah(
                number: apiVerse.verseNumber,
                arabic: arabicText,
                translation: translation,
                surahNumber: surahNumber,
                juzNumber: apiVerse.juzNumber,
                pageNumber: apiVerse.pageNumber
            )
        }
        
        let revelationType: RevelationType = apiSurah.revelationPlace.lowercased() == "makkah" ? .meccan : .medinan
        
        let surah = Surah(
            number: apiSurah.id,
            arabicName: apiSurah.nameArabic,
            englishName: apiSurah.nameSimple,
            transliteration: apiSurah.nameComplex,
            ayahCount: apiSurah.versesCount,
            revelationType: revelationType,
            ayahs: ayahs
        )
        
        print("✅ QuranAPI: Successfully converted \(ayahs.count) ayahs for surah \(surah.englishName), pagination: \(paginationInfo?.currentPage ?? 1)/\(paginationInfo?.totalPages ?? 1)")
        
        return (surah, ayahs, paginationInfo)
    }
    
    // MARK: - Fetch Verses by Page
    
    func fetchVersesByPage(pageNumber: Int, translationLanguage: String = "en") async throws -> [Ayah] {
        let url = URL(string: "\(baseURL)/verses/by_page/\(pageNumber)?translations=20&translation_fields=text,language_name&fields=text_uthmani,text_simple")!
        print("📡 QuranAPI: Fetching verses by page \(pageNumber) from \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ QuranAPI: Invalid HTTP response for page \(pageNumber)")
            throw QuranAPIError.invalidResponse
        }
        
        print("📥 QuranAPI: Page \(pageNumber) response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ QuranAPI: HTTP error for page \(pageNumber): \(httpResponse.statusCode)")
            throw QuranAPIError.invalidResponse
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 QuranAPI: Page response (first 2000 chars): \(String(responseString.prefix(2000)))")
        }
        
        // Try different response formats
        var apiVerses: [APIVerse]
        if let versesResponse = try? decoder.decode(VersesResponse.self, from: data) {
            apiVerses = versesResponse.verses
            print("✅ QuranAPI: Page \(pageNumber) decoded as VersesResponse, found \(apiVerses.count) verses")
        } else if let wrapperResponse = try? decoder.decode(APIResponse<VersesWrapper>.self, from: data),
                  let verses = wrapperResponse.verses?.verses {
            apiVerses = verses
            print("✅ QuranAPI: Page \(pageNumber) decoded as APIResponse<VersesWrapper>, found \(apiVerses.count) verses")
        } else if let arrayResponse = try? decoder.decode(APIResponse<[APIVerse]>.self, from: data),
                  let verses = arrayResponse.verses ?? arrayResponse.data {
            apiVerses = verses
            print("✅ QuranAPI: Page \(pageNumber) decoded as APIResponse<[APIVerse]>, found \(apiVerses.count) verses")
        } else {
            print("❌ QuranAPI: Failed to decode page \(pageNumber) response")
            throw QuranAPIError.noData
        }
        
        let ayahs = apiVerses.map { apiVerse in
            // Clean translation text - remove HTML tags and footnotes
            var translation = apiVerse.translations?.first?.text ?? ""
            translation = cleanTranslationText(translation)
            
            // Handle missing text - use verse key as fallback if no text available
            let arabicText = apiVerse.textUthmani ?? apiVerse.textSimple ?? apiVerse.verseKey
            
            return Ayah(
                number: apiVerse.verseNumber,
                arabic: arabicText,
                translation: translation,
                surahNumber: extractSurahNumber(from: apiVerse.verseKey),
                juzNumber: apiVerse.juzNumber,
                pageNumber: apiVerse.pageNumber
            )
        }
        
        print("✅ QuranAPI: Successfully converted \(ayahs.count) ayahs for page \(pageNumber)")
        return ayahs
    }
    
    // MARK: - Fetch Verses by Juz
    
    func fetchVersesByJuz(juzNumber: Int, translationLanguage: String = "en") async throws -> [Ayah] {
        let url = URL(string: "\(baseURL)/verses/by_juz/\(juzNumber)?translations=20&translation_fields=text,language_name&fields=text_uthmani,text_simple")!
        print("📡 QuranAPI: Fetching verses by juz \(juzNumber) from \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ QuranAPI: Invalid HTTP response for juz \(juzNumber)")
            throw QuranAPIError.invalidResponse
        }
        
        print("📥 QuranAPI: Juz \(juzNumber) response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ QuranAPI: HTTP error for juz \(juzNumber): \(httpResponse.statusCode)")
            throw QuranAPIError.invalidResponse
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 QuranAPI: Juz response (first 2000 chars): \(String(responseString.prefix(2000)))")
        }
        
        // Try different response formats
        var apiVerses: [APIVerse]
        if let versesResponse = try? decoder.decode(VersesResponse.self, from: data) {
            apiVerses = versesResponse.verses
            print("✅ QuranAPI: Juz \(juzNumber) decoded as VersesResponse, found \(apiVerses.count) verses")
        } else if let wrapperResponse = try? decoder.decode(APIResponse<VersesWrapper>.self, from: data),
                  let verses = wrapperResponse.verses?.verses {
            apiVerses = verses
            print("✅ QuranAPI: Juz \(juzNumber) decoded as APIResponse<VersesWrapper>, found \(apiVerses.count) verses")
        } else if let arrayResponse = try? decoder.decode(APIResponse<[APIVerse]>.self, from: data),
                  let verses = arrayResponse.verses ?? arrayResponse.data {
            apiVerses = verses
            print("✅ QuranAPI: Juz \(juzNumber) decoded as APIResponse<[APIVerse]>, found \(apiVerses.count) verses")
        } else {
            print("❌ QuranAPI: Failed to decode juz \(juzNumber) response")
            throw QuranAPIError.noData
        }
        
        let ayahs = apiVerses.map { apiVerse in
            // Clean translation text - remove HTML tags and footnotes
            var translation = apiVerse.translations?.first?.text ?? ""
            translation = cleanTranslationText(translation)
            
            // Handle missing text - use verse key as fallback if no text available
            let arabicText = apiVerse.textUthmani ?? apiVerse.textSimple ?? apiVerse.verseKey
            
            return Ayah(
                number: apiVerse.verseNumber,
                arabic: arabicText,
                translation: translation,
                surahNumber: extractSurahNumber(from: apiVerse.verseKey),
                juzNumber: apiVerse.juzNumber,
                pageNumber: apiVerse.pageNumber
            )
        }
        
        print("✅ QuranAPI: Successfully converted \(ayahs.count) ayahs for juz \(juzNumber)")
        return ayahs
    }
    
    // MARK: - Helper Methods
    
    /// Clean translation text by removing HTML tags, footnotes, and extra formatting
    private func cleanTranslationText(_ text: String) -> String {
        var cleaned = text
        
        // Remove HTML sup tags and their content (footnotes like <sup>1</sup>)
        cleaned = cleaned.replacingOccurrences(
            of: "<sup[^>]*>.*?</sup>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove any remaining HTML tags
        cleaned = cleaned.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        
        // Clean up multiple spaces and trim whitespace
        cleaned = cleaned.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespaces)
        
        // Remove trailing punctuation artifacts (like "-" at end of lines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " -"))
        
        return cleaned
    }
    
    private func extractSurahNumber(from verseKey: String) -> Int {
        // Verse key format: "1:1" (surah:ayah)
        let components = verseKey.split(separator: ":")
        return Int(components.first ?? "0") ?? 0
    }
}

// MARK: - Error Types

enum QuranAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response"
        case .noData:
            return "No data received from API"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
