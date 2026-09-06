import Testing
import Foundation
import SwiftData
import DomainKit
import DomainKitTestSupport
@testable import DataKit

/// The only on-disk coverage in the package. Everything else about the cache is
/// designed to fail quietly — reads are `try?`, writes roll back, and the
/// container's own initialiser returns nil — so this is the one place a storage
/// mistake can be made loud.
@Suite("MovieCacheContainer")
final class MovieCacheContainerTests {
    private let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("The store lands at the configured path")
    func writesToTheConfiguredDirectory() async throws {
        let store = GenreCacheStore(modelContainer: try MovieCacheContainer.make(in: directory))

        await store.save(Genre.fixtures)

        // The regression test for default.store: an ignored URL puts this file
        // somewhere shared, where the future Watchlist container collides with it.
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "MovieCache.store").path))
    }

    @Test("Containers in different directories share nothing")
    func keepsDirectoriesIndependent() async throws {
        let other = directory.appending(path: "other")
        defer { try? FileManager.default.removeItem(at: other) }

        let first = GenreCacheStore(modelContainer: try MovieCacheContainer.make(in: directory))
        let second = GenreCacheStore(modelContainer: try MovieCacheContainer.make(in: other))

        await first.save(Genre.fixtures)

        #expect(await second.genres() == nil)
    }

    @Test("The default directory is inside Caches, not Application Support")
    func defaultsToCaches() {
        // Disposable data: excluded from backup, and purgeable by the OS, which
        // is the only eviction this cache has.
        #expect(MovieCacheContainer.defaultDirectory.path.contains("/Caches/"))
    }
}
