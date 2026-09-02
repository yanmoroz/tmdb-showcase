import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

/// The decorators over the *real* repositories and a stubbed transport.
///
/// `CachingMoviesRepositoryTests` and `CachingGenresRepositoryTests` stub at the
/// repository level, so they never run `AppError.init(transportError:)` — the
/// mapping from `URLError` to `.network(_)` that decides whether the fallback
/// fires at all. Everything below goes through it.
@Suite("The cached stack")
struct CachedStackTests {
    @Test("A page warmed online is served when the transport fails")
    func servesWarmedPageWhenTransportFails() async throws {
        let cache = MovieCache(container: try MovieCacheContainer.make(inMemory: true))

        let online = StubURLProtocol.makeSession(.json(try TestFixtures.data("popular_page1")))
        _ = try await makeMovies(online, cache).movies(query: .popular, page: 1)

        let offline = StubURLProtocol.makeSession(.transport(.notConnectedToInternet))
        let served = try await makeMovies(offline, cache).movies(query: .popular, page: 1)

        #expect(served.items.first?.title == "Dune: Part Two")
        // It still tried the network first — the cache is a fallback, not a shortcut.
        #expect(offline.recordedRequests.count == 1)
    }

    @Test("A geo-block reaches the caller even with a warm page")
    func neverMasksRegionBlockThroughTheRealStack() async throws {
        let cache = MovieCache(container: try MovieCacheContainer.make(inMemory: true))

        let online = StubURLProtocol.makeSession(.json(try TestFixtures.data("popular_page1")))
        _ = try await makeMovies(online, cache).movies(query: .popular, page: 1)

        // 403 with an empty body is the CDN block, classified in DataKit.
        let blocked = StubURLProtocol.makeSession(.status(403))
        await #expect(throws: AppError.regionRestricted) {
            try await makeMovies(blocked, cache).movies(query: .popular, page: 1)
        }
    }

    /// The read-through stated at the transport: zero HTTP requests, not merely
    /// zero calls to a stubbed repository.
    @Test("A fresh catalogue issues no request at all")
    func freshCatalogueIssuesNoRequest() async throws {
        let cache = MovieCache(container: try MovieCacheContainer.make(inMemory: true))
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let online = StubURLProtocol.makeSession(.json(try TestFixtures.data("genres")))
        _ = try await makeGenres(online, cache, now: now).genres()
        #expect(online.recordedRequests.count == 1)

        let second = StubURLProtocol.makeSession(.json(try TestFixtures.data("genres")))
        _ = try await makeGenres(second, cache, now: now.addingTimeInterval(3600)).genres()

        #expect(second.recordedRequests.isEmpty)
    }

    // MARK: - Factory

    private func makeMovies(_ stub: StubSession, _ cache: MovieCache) -> CachingMoviesRepository {
        CachingMoviesRepository(
            wrapping: TMDBMoviesRepository(configuration: .test, session: stub.session),
            cache: cache
        )
    }

    private func makeGenres(_ stub: StubSession, _ cache: MovieCache, now: Date) -> CachingGenresRepository {
        CachingGenresRepository(
            wrapping: TMDBGenresRepository(configuration: .test, session: stub.session),
            cache: cache,
            window: CacheWindow(duration: CacheFreshness.genres, clock: { now })
        )
    }
}
