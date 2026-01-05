//
//  DataCacheService.swift
//  LockIn
//
//  Local data cache for instant app launch with last-known data.
//  Convex subscriptions are the source of truth - this is just for fast startup.
//

import Foundation

/// Thread-safe local data cache using file-based JSON storage.
/// Provides instant app launch by loading cached data before Convex subscriptions connect.
actor DataCacheService {
    static let shared = DataCacheService()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default

    /// Cache keys for different data types
    enum CacheKey: String, CaseIterable {
        case goals
        case todos
        case goalTodos
    }

    /// Base cache directory in Caches folder
    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LockInDataCache", isDirectory: true)
    }

    private init() {
        // Ensure cache directory exists
        createCacheDirectoryIfNeeded()
    }

    // MARK: - Public API

    /// Load cached data for a given key
    /// Returns nil if no cache exists or decoding fails
    func load<T: Codable>(_ key: CacheKey) -> T? {
        let fileURL = cacheFileURL(for: key)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode(T.self, from: data)
            return decoded
        } catch {
            print("[DataCache] Failed to load \(key.rawValue): \(error.localizedDescription)")
            return nil
        }
    }

    /// Save data to cache for a given key
    /// Saves asynchronously to avoid blocking the caller
    func save<T: Codable>(_ data: T, for key: CacheKey) {
        let fileURL = cacheFileURL(for: key)

        do {
            let encoded = try encoder.encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("[DataCache] Failed to save \(key.rawValue): \(error.localizedDescription)")
        }
    }

    /// Clear a specific cache
    func clear(_ key: CacheKey) {
        let fileURL = cacheFileURL(for: key)

        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                print("[DataCache] Failed to clear \(key.rawValue): \(error.localizedDescription)")
            }
        }
    }

    /// Clear all cached data (call on logout)
    func clearAll() {
        for key in CacheKey.allCases {
            clear(key)
        }
        print("[DataCache] All caches cleared")
    }

    // MARK: - Private Helpers

    private func cacheFileURL(for key: CacheKey) -> URL {
        cacheDirectory.appendingPathComponent("\(key.rawValue).json")
    }

    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                print("[DataCache] Failed to create cache directory: \(error.localizedDescription)")
            }
        }
    }
}
