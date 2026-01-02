//
//  ThumbnailCache.swift
//  LockIn
//
//  Created by Claude on 01/01/26.
//

import UIKit

/// In-memory thumbnail cache using NSCache for efficient image loading.
/// Prevents blocking the main thread with disk I/O and avoids redundant loads.
actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()
    private var loadingTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Max 100 thumbnails
        cache.totalCostLimit = 50 * 1024 * 1024 // ~50MB
    }

    /// Get cached thumbnail or load from disk asynchronously
    func thumbnail(for url: URL) async -> UIImage? {
        let key = url.path as NSString

        // Check cache first
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // Check if already loading
        if let existingTask = loadingTasks[url.path] {
            return await existingTask.value
        }

        // Start new loading task
        let task = Task<UIImage?, Never> {
            await loadThumbnail(from: url)
        }
        loadingTasks[url.path] = task

        let image = await task.value
        loadingTasks[url.path] = nil

        return image
    }

    /// Load thumbnail from disk on background thread
    private func loadThumbnail(from url: URL) async -> UIImage? {
        // Perform disk I/O on background thread
        let image: UIImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard FileManager.default.fileExists(atPath: url.path),
                      let data = try? Data(contentsOf: url),
                      let loadedImage = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: loadedImage)
            }
        }

        // Cache the result
        if let image = image {
            let key = url.path as NSString
            // Estimate cost based on image size
            let cost = Int(image.size.width * image.size.height * image.scale * 4)
            cache.setObject(image, forKey: key, cost: cost)
        }

        return image
    }

    /// Prefetch thumbnails for a list of URLs
    func prefetch(urls: [URL]) {
        Task {
            for url in urls {
                _ = await thumbnail(for: url)
            }
        }
    }

    /// Remove specific thumbnail from cache
    func remove(for url: URL) {
        cache.removeObject(forKey: url.path as NSString)
    }

    /// Clear all cached thumbnails
    func clearAll() {
        cache.removeAllObjects()
        loadingTasks.removeAll()
    }
}
