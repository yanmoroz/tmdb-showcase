import Testing
import Foundation
import SwiftData
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("SwiftDataWatchlistRepository")
struct SwiftDataWatchlistRepositoryTests {
    @Test("A saved film comes back whole")
    func roundTripsAMovie() async throws {
        let repository = try makeRepository()
        let movie = Movie.fixture(id: 42, title: "Saved Film")

        try await repository.save(movie)

        #expect(try await repository.savedMovies() == [movie])
    }

    @Test("Identifiers follow what is saved and removed")
    func tracksIdentifiers() async throws {
        let repository = try makeRepository()

        #expect(try await repository.savedIdentifiers().isEmpty)

        try await repository.save(.fixture(id: 1))
        try await repository.save(.fixture(id: 2))
        #expect(try await repository.savedIdentifiers() == [1, 2])

        try await repository.remove(id: 1)
        #expect(try await repository.savedIdentifiers() == [2])
    }

    @Test("Saving the same film twice replaces rather than duplicates")
    func savingTwiceDoesNotDuplicate() async throws {
        let repository = try makeRepository()

        try await repository.save(.fixture(id: 7, title: "First"))
        try await repository.save(.fixture(id: 7, title: "Second"))

        let saved = try await repository.savedMovies()
        #expect(saved.count == 1)
        #expect(saved.first?.title == "Second")
    }

    /// The caller wanted it gone, and it is — an error here would make every
    /// toggle need to know the current state before acting.
    @Test("Removing a film that was never saved is not an error")
    func removingAnAbsentFilmSucceeds() async throws {
        let repository = try makeRepository()

        try await repository.remove(id: 999)

        #expect(try await repository.savedIdentifiers().isEmpty)
    }

    @Test("The list reads newest first")
    func ordersNewestFirst() async throws {
        let repository = try makeRepository()
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)

        try await repository.save(.fixture(id: 1, title: "Older"), at: earlier)
        try await repository.save(.fixture(id: 2, title: "Newer"), at: earlier.addingTimeInterval(60))

        #expect(try await repository.savedMovies().map(\.title) == ["Newer", "Older"])
    }

    @Test("The stand-in reports that it cannot save")
    func unavailableWatchlistReportsStorageFailures() async throws {
        let repository = UnavailableWatchlist()

        #expect(try await repository.savedIdentifiers().isEmpty)
        await #expect(throws: AppError.storage) { try await repository.save(.fixture()) }
        await #expect(throws: AppError.storage) { try await repository.remove(id: 1) }
    }

    private func makeRepository() throws -> SwiftDataWatchlistRepository {
        SwiftDataWatchlistRepository(modelContainer: try WatchlistContainer.make(inMemory: true))
    }
}

@Suite("WatchlistContainer")
final class WatchlistContainerTests {
    private let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("The store lands at the configured path")
    func writesToTheConfiguredDirectory() async throws {
        let repository = SwiftDataWatchlistRepository(
            modelContainer: try WatchlistContainer.make(in: directory)
        )

        try await repository.save(.fixture())

        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Watchlist.store").path))
    }

    /// The reader's own data is backed up and never purged; the cache is neither.
    /// Sharing a directory would put one policy on both.
    @Test("It lives in Application Support, away from the cache")
    func defaultsToApplicationSupport() {
        #expect(WatchlistContainer.defaultDirectory.path.contains("/Application Support/"))
        #expect(WatchlistContainer.defaultDirectory != MovieCacheContainer.defaultDirectory)
    }
}
