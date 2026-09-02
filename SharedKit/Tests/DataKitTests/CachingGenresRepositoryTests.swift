import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("CachingGenresRepository")
struct CachingGenresRepositoryTests {
    /// A fixed clock and a short window. Staleness is arranged by choosing the
    /// timestamp a catalogue was written with, so nothing here waits on time.
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static let window: TimeInterval = 3600

    @Test("A cold cache goes to the network and writes through")
    func writesThroughOnColdCache() async throws {
        let (sut, remote, cache) = try makeSUT()

        #expect(try await sut.genres() == Genre.fixtures)
        #expect(await cache.genres.genres()?.genres == Genre.fixtures)
        #expect(await remote.genresCalls.count == 1)
    }

    /// The point of the read-through: the filter screen stops paying for a
    /// request every time it opens.
    @Test("A fresh catalogue is served without touching the network")
    func servesFreshCatalogueWithoutNetwork() async throws {
        let (sut, remote, cache) = try makeSUT()
        await cache.genres.save(Genre.fixtures, at: Self.now.addingTimeInterval(-60))

        #expect(try await sut.genres() == Genre.fixtures)
        #expect(await remote.genresCalls.isEmpty)
    }

    @Test("A catalogue older than the window is refreshed")
    func refreshesStaleCatalogue() async throws {
        let replacement = [Genre.fixture(id: 99, name: "Documentary")]
        let (sut, remote, cache) = try makeSUT(genres: .success(replacement))
        await cache.genres.save(Genre.fixtures, at: Self.stale)

        #expect(try await sut.genres() == replacement)
        #expect(await remote.genresCalls.count == 1)
        #expect(await cache.genres.genres()?.genres == replacement)
    }

    @Test("A refreshed catalogue is stamped with the injected clock")
    func stampsWriteWithInjectedClock() async throws {
        let (sut, _, cache) = try makeSUT()

        _ = try await sut.genres()

        // Not Date.now: a write stamped with the real clock would make the
        // window untestable and could never be reasoned about.
        #expect(await cache.genres.genres()?.updatedAt == Self.now)
    }

    /// The window decides whether the network is skipped, never whether old rows
    /// are usable. Once the network has failed, stale genres beat an empty screen.
    @Test("A stale catalogue still answers when the network fails")
    func servesStaleCatalogueOnFailure() async throws {
        let (sut, remote, cache) = try makeSUT(genres: .failure(.network(.offline)))
        await cache.genres.save(Genre.fixtures, at: Self.stale)

        #expect(try await sut.genres() == Genre.fixtures)
        #expect(await remote.genresCalls.count == 1)
    }

    @Test("A cold cache plus a failure still fails")
    func rethrowsWhenCacheIsCold() async throws {
        let (sut, _, _) = try makeSUT(genres: .failure(.network(.timedOut)))

        await #expect(throws: AppError.network(.timedOut)) {
            try await sut.genres()
        }
    }

    /// Note the stale seed: with a fresh catalogue the network is never reached,
    /// so these cases would short-circuit and stop testing the policy at all.
    @Test("Only a transport failure is answered from the cache", arguments: [
        AppError.regionRestricted,
        .cancelled,
        .unauthorized,
        .rateLimited,
        .notFound,
        .decoding,
        .server(statusCode: 503),
        .unknown,
    ])
    func neverMasksOtherFailures(error: AppError) async throws {
        let (sut, _, cache) = try makeSUT(genres: .failure(error))
        await cache.genres.save(Genre.fixtures, at: Self.stale)

        await #expect(throws: error) {
            try await sut.genres()
        }
    }

    /// One blank answer from TMDB would otherwise hide the real catalogue for a
    /// week — network-first used to heal that on the next open.
    @Test("An empty cached catalogue is always revalidated")
    func alwaysRevalidatesEmptyCatalogue() async throws {
        let (sut, remote, cache) = try makeSUT()
        await cache.genres.save([], at: Self.now.addingTimeInterval(-60))

        #expect(try await sut.genres() == Genre.fixtures)
        #expect(await remote.genresCalls.count == 1)
    }

    // MARK: - Factory

    private static var stale: Date { now.addingTimeInterval(-(window + 60)) }

    private func makeSUT(
        genres: Result<[Genre], AppError> = .success(Genre.fixtures)
    ) throws -> (sut: CachingGenresRepository, remote: GenresRepositoryStub, cache: MovieCache) {
        let remote = GenresRepositoryStub(genresResult: genres)
        let cache = MovieCache(container: try MovieCacheContainer.make(inMemory: true))
        let sut = CachingGenresRepository(
            wrapping: remote,
            cache: cache,
            window: CacheWindow(duration: Self.window, clock: { Self.now })
        )
        return (sut, remote, cache)
    }
}
