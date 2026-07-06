//
//  FirebaseBookmarkService.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

/// Service for managing Quran bookmarks in Firestore
@MainActor
class FirebaseBookmarkService {
    static let shared = FirebaseBookmarkService()
    
    private let db = Firestore.firestore()
    private let collectionName = "bookmarks"
    
    private init() {
        print("🔧 FirebaseBookmarkService: Initialized")
    }
    
    // MARK: - Save Bookmarks
    
    /// Save all bookmarks for the current user
    func saveBookmarks(_ bookmarks: [Bookmark], userId: String) async throws {
        print("💾 FirebaseBookmarkService: Saving \(bookmarks.count) bookmarks for user \(userId)")
        
        // Delete existing bookmarks for this user first
        let existingBookmarks = try await fetchBookmarks(userId: userId)
        for existingBookmark in existingBookmarks {
            try await deleteBookmark(bookmarkId: existingBookmark.id.uuidString, userId: userId)
        }
        
        // Save new bookmarks
        for bookmark in bookmarks {
            let bookmarkData: [String: Any] = [
                "id": bookmark.id.uuidString,
                "userId": userId,
                "surahNumber": bookmark.surahNumber,
                "ayahNumber": bookmark.ayahNumber,
                "timestamp": Timestamp(date: bookmark.timestamp),
                "note": bookmark.note ?? NSNull()
            ]
            
            try await db.collection(collectionName).document(bookmark.id.uuidString).setData(bookmarkData)
            print("✅ FirebaseBookmarkService: Saved bookmark \(bookmark.id) for surah \(bookmark.surahNumber), ayah \(bookmark.ayahNumber)")
        }
        
        print("✅ FirebaseBookmarkService: Successfully saved all bookmarks")
    }
    
    // MARK: - Fetch Bookmarks
    
    /// Fetch all bookmarks for the current user
    func fetchBookmarks(userId: String) async throws -> [Bookmark] {
        print("📡 FirebaseBookmarkService: Fetching bookmarks for user \(userId)")
        
        let snapshot = try await db.collection(collectionName)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        var fetchedBookmarks: [Bookmark] = []
        
        for document in snapshot.documents {
            if let bookmark = decodeBookmark(from: document.data(), documentId: document.documentID) {
                fetchedBookmarks.append(bookmark)
            }
        }
        
        print("✅ FirebaseBookmarkService: Fetched \(fetchedBookmarks.count) bookmarks")
        return fetchedBookmarks
    }
    
    // MARK: - Add/Update Bookmark
    
    /// Add or update a single bookmark
    func saveBookmark(_ bookmark: Bookmark, userId: String) async throws {
        print("💾 FirebaseBookmarkService: Saving bookmark \(bookmark.id) for surah \(bookmark.surahNumber)")
        
        // Check if there's an existing bookmark for this surah
        let existingBookmarks = try await fetchBookmarks(userId: userId)
        if let existingBookmark = existingBookmarks.first(where: { $0.surahNumber == bookmark.surahNumber }) {
            // Delete the old bookmark if it's different
            if existingBookmark.id != bookmark.id {
                try await deleteBookmark(bookmarkId: existingBookmark.id.uuidString, userId: userId)
            }
        }
        
        let bookmarkData: [String: Any] = [
            "id": bookmark.id.uuidString,
            "userId": userId,
            "surahNumber": bookmark.surahNumber,
            "ayahNumber": bookmark.ayahNumber,
            "timestamp": Timestamp(date: bookmark.timestamp),
            "note": bookmark.note ?? NSNull()
        ]
        
        try await db.collection(collectionName).document(bookmark.id.uuidString).setData(bookmarkData)
        print("✅ FirebaseBookmarkService: Bookmark saved successfully")
    }
    
    // MARK: - Delete Bookmark
    
    /// Delete a bookmark
    func deleteBookmark(bookmarkId: String, userId: String) async throws {
        print("🗑️ FirebaseBookmarkService: Deleting bookmark \(bookmarkId)")
        
        // Verify ownership before deleting
        let documentRef = db.collection(collectionName).document(bookmarkId)
        let document = try await documentRef.getDocument()
        
        guard let data = document.data(),
              let bookmarkUserId = data["userId"] as? String,
              bookmarkUserId == userId else {
            print("❌ FirebaseBookmarkService: Bookmark not found or user mismatch")
            throw NSError(domain: "FirebaseBookmarkService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Bookmark not found or access denied"])
        }
        
        try await documentRef.delete()
        print("✅ FirebaseBookmarkService: Bookmark deleted successfully")
    }
    
    // MARK: - Delete All Bookmarks
    
    /// Delete all bookmarks for a user (useful for account deletion)
    func deleteAllBookmarks(userId: String) async throws {
        print("🗑️ FirebaseBookmarkService: Deleting all bookmarks for user \(userId)")
        
        let snapshot = try await db.collection(collectionName)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for document in snapshot.documents {
            try await document.reference.delete()
        }
        
        print("✅ FirebaseBookmarkService: Deleted \(snapshot.documents.count) bookmarks")
    }
    
    // MARK: - Helper Methods
    
    /// Decode Bookmark from Firestore data
    private func decodeBookmark(from data: [String: Any], documentId: String) -> Bookmark? {
        guard let surahNumber = data["surahNumber"] as? Int,
              let ayahNumber = data["ayahNumber"] as? Int else {
            print("❌ FirebaseBookmarkService: Invalid bookmark data")
            return nil
        }
        
        let id = UUID(uuidString: documentId) ?? UUID()
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let note = data["note"] as? String
        
        return Bookmark(
            id: id,
            surahNumber: surahNumber,
            ayahNumber: ayahNumber,
            timestamp: timestamp,
            note: note
        )
    }
}
