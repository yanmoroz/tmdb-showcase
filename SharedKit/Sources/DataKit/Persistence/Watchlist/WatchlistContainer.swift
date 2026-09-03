import Foundation
import SwiftData

/// `Application Support/Watchlist/Watchlist.store`.
///
/// Every choice here is the opposite of ``MovieCacheContainer``'s, and for the
/// same reason: that one is disposable. Application Support rather than Caches,
/// because the OS may purge Caches and this is the reader's own data; backed up
/// rather than excluded; migrated rather than deleted.
///
/// Named, and in its own directory, so it cannot collide with the cache — which
/// is exactly the failure `MovieCacheContainer` was renamed to avoid.
enum WatchlistContainer {
    static let defaultDirectory = URL.applicationSupportDirectory
        .appending(path: "Watchlist", directoryHint: .isDirectory)

    /// `directory` is ignored when `inMemory` is true.
    static func make(inMemory: Bool = false, in directory: URL = defaultDirectory) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = ModelConfiguration(url: directory.appending(path: "Watchlist.store"))
        }

        return try ModelContainer(
            for: Schema(versionedSchema: WatchlistSchemaV1.self),
            migrationPlan: WatchlistMigrationPlan.self,
            configurations: configuration
        )
    }
}
