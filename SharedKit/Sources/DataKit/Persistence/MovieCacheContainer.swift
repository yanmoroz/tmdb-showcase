import Foundation
import SwiftData

/// One file on disk for the Movies feature's cache. The Watchlist gets its own
/// container: this one is disposable, and a schema change here is a delete
/// rather than a migration.
enum MovieCacheContainer {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MovieCacheSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
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
