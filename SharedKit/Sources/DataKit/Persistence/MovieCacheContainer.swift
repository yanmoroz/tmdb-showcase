import Foundation
import SwiftData

/// `Caches/MovieCache/MovieCache.store`. The Watchlist gets its own container in
/// its own directory: this one is disposable, so a schema change is a delete
/// rather than a migration.
///
/// Caches rather than Application Support on purpose — it is excluded from
/// backup, and the OS may purge it under storage pressure, which is the only
/// eviction this cache has. Its own subdirectory keeps a purge from taking the
/// store while leaving the SQLite sidecars behind.
///
/// Naming it also matters: two containers both defaulting to `default.store`
/// with different schemas fail to open, and `MovieCache.init?()` would swallow
/// that as "run uncached" — a cache that silently stops working.
enum MovieCacheContainer {
    static let defaultDirectory = URL.cachesDirectory
        .appending(path: "MovieCache", directoryHint: .isDirectory)

    /// `directory` is ignored when `inMemory` is true.
    static func make(inMemory: Bool = false, in directory: URL = defaultDirectory) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = ModelConfiguration(url: directory.appending(path: "MovieCache.store"))
        }

        return try ModelContainer(for: Schema(MovieCacheSchema.models), configurations: configuration)
    }
}

extension ModelContext {
    /// A cache write that fails must leave the store as it was, not half applied.
    func commitOrRollback() {
        do {
            try save()
        } catch {
            rollback()
        }
    }
}
