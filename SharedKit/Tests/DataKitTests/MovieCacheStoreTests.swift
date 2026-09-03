import Testing
import Foundation
import SwiftData
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("MovieCacheStore")
struct MovieCacheStoreTests {
    @Test("A page survives the round trip whole")
    func roundTripsAPage() async throws {
        let store = try makeStore()
        let key = MoviesQueryKey(.popular)
        let page = Page.fixture(
            items: Movie.fixtures(count: 3),
            page: 1,
            totalPages: 17,
            totalResults: 334
        )

        await store.save(page, for: key)

        #expect(await store.page(for: key) == page)
    }

    @Test("Row order is restored from position, not from the relationship")
    func restoresRowOrder() async throws {
        let store = try makeStore()
        let key = MoviesQueryKey(.popular)
        // Descending ids: insertion order and id order disagree, so a read that
        // leans on either one shows up here.
        let movies = Array(Movie.fixtures(count: 12).reversed())

        await store.save(Page.fixture(items: movies), for: key)

        let restored = try #require(await store.page(for: key))
        #expect(restored.items.map(\.id) == movies.map(\.id))
    }

    @Test("Saving again replaces the page instead of appending to it")
    func overwritesAPage() async throws {
        let store = try makeStore()
        let key = MoviesQueryKey(.popular)

        await store.save(Page.fixture(items: Movie.fixtures(count: 5)), for: key)
        let replacement = Page.fixture(items: Movie.fixtures(count: 2, startingAt: 90), totalPages: 4)
        await store.save(replacement, for: key)

        #expect(await store.page(for: key) == replacement)
        // The five rows the first save wrote must be gone, not orphaned.
        #expect(try await store.countOfCachedMovies() == 2)
    }

    @Test("An unknown key is a miss")
    func missesUnknownKey() async throws {
        let store = try makeStore()

        #expect(await store.page(for: MoviesQueryKey(.popular)) == nil)
    }

    @Test("An empty page is remembered as empty, not as a miss")
    func distinguishesEmptyPageFromMiss() async throws {
        let store = try makeStore()
        let key = MoviesQueryKey(.search(.fixture("nothingmatchesthis")))

        await store.save(Page.empty(), for: key)

        let restored = await store.page(for: key)
        #expect(restored != nil)
        #expect(restored?.isEmpty == true)
    }

    @Test("Keys address their own rows")
    func keepsQueriesApart() async throws {
        let store = try makeStore()
        let popular = MoviesQueryKey(.popular)
        let search = MoviesQueryKey(.search(.fixture("dune")))

        await store.save(Page.fixture(items: Movie.fixtures(count: 3)), for: popular)
        await store.save(Page.fixture(items: Movie.fixtures(count: 7, startingAt: 50)), for: search)

        #expect(await store.page(for: popular)?.items.count == 3)
        #expect(await store.page(for: search)?.items.count == 7)
    }

    // MARK: - Details

    @Test("Details survive the round trip whole")
    func roundTripsDetails() async throws {
        let store = try makeStore()
        let details = MovieDetails.fixture(
            id: 42,
            genres: [.fixture(id: 18, name: "Drama"), .fixture(id: 28, name: "Action")],
            homepage: URL(string: "https://example.com/film")
        )

        await store.save(details)

        #expect(await store.details(for: 42) == details)
    }

    @Test("Absent fields come back absent, not defaulted")
    func roundTripsMissingDetailFields() async throws {
        let store = try makeStore()
        let sparse = MovieDetails.fixture(
            id: 7,
            tagline: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            runtime: nil,
            genres: [],
            homepage: nil
        )

        await store.save(sparse)

        #expect(await store.details(for: 7) == sparse)
    }

    @Test("Saving details again replaces them")
    func overwritesDetails() async throws {
        let store = try makeStore()
        await store.save(MovieDetails.fixture(id: 42, title: "Old"))

        await store.save(MovieDetails.fixture(id: 42, title: "New"))

        #expect(await store.details(for: 42)?.title == "New")
        #expect(try await store.countOfCachedDetails() == 1)
    }

    @Test("Unknown details are a miss")
    func missesUnknownDetails() async throws {
        let store = try makeStore()

        #expect(await store.details(for: 42) == nil)
    }

    @Test("Details are addressed by movie id")
    func keepsDetailsApart() async throws {
        let store = try makeStore()

        await store.save(MovieDetails.fixture(id: 1, title: "First"))
        await store.save(MovieDetails.fixture(id: 2, title: "Second"))

        #expect(await store.details(for: 1)?.title == "First")
        #expect(await store.details(for: 2)?.title == "Second")
    }

    // MARK: - Retention

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static var beyondWindow: Date { now.addingTimeInterval(-(CacheRetention.maxAge + 60)) }

    @Test("A page past the window is swept on the next write")
    func dropsPagesPastTheWindow() async throws {
        let store = try makeStore()
        let stale = MoviesQueryKey(.search(.fixture("watched once")))

        await store.save(Page.fixture(items: Movie.fixtures(count: 3)), for: stale, at: Self.beyondWindow)
        await store.save(Page.fixture(items: Movie.fixtures(count: 3)), for: MoviesQueryKey(.popular), at: Self.now)

        #expect(await store.page(for: stale) == nil)
        #expect(await store.page(for: MoviesQueryKey(.popular)) != nil)
    }

    @Test("A page inside the window survives")
    func keepsPagesInsideTheWindow() async throws {
        let store = try makeStore()
        let recent = MoviesQueryKey(.search(.fixture("yesterday")))

        await store.save(Page.fixture(items: Movie.fixtures(count: 3)), for: recent, at: Self.now.addingTimeInterval(-3600))
        await store.save(Page.fixture(items: Movie.fixtures(count: 3)), for: MoviesQueryKey(.popular), at: Self.now)

        #expect(await store.page(for: recent) != nil)
    }

    /// Cascade is why rows are deleted one at a time: a swept page must take its
    /// movies with it, or the table grows anyway.
    @Test("A swept page takes its movie rows with it")
    func sweepsMovieRowsWithTheirPage() async throws {
        let store = try makeStore()

        await store.save(
            Page.fixture(items: Movie.fixtures(count: 5)),
            for: MoviesQueryKey(.search(.fixture("old"))),
            at: Self.beyondWindow
        )
        await store.save(
            Page.fixture(items: Movie.fixtures(count: 2, startingAt: 90)),
            for: MoviesQueryKey(.popular),
            at: Self.now
        )

        #expect(try await store.countOfCachedMovies() == 2)
    }

    @Test("Beyond the cap the oldest pages go first")
    func capsThePageCount() async throws {
        let store = try makeStore()

        // All inside the window, so only the cap can be what removes them.
        for index in 0...CacheRetention.maxPages {
            await store.save(
                Page.fixture(items: Movie.fixtures(count: 1)),
                for: MoviesQueryKey(.search(.fixture("query \(index)"))),
                at: Self.now.addingTimeInterval(TimeInterval(index))
            )
        }

        #expect(try await store.countOfCachedPages() == CacheRetention.maxPages)
        #expect(await store.page(for: MoviesQueryKey(.search(.fixture("query 0")))) == nil)
        #expect(await store.page(for: MoviesQueryKey(.search(.fixture("query \(CacheRetention.maxPages)")))) != nil)
    }

    @Test("Details past the window are swept too")
    func dropsDetailsPastTheWindow() async throws {
        let store = try makeStore()

        await store.save(MovieDetails.fixture(id: 7), at: Self.beyondWindow)
        await store.save(MovieDetails.fixture(id: 8), at: Self.now)

        #expect(await store.details(for: 7) == nil)
        #expect(await store.details(for: 8) != nil)
    }

    /// Nothing but a details write used to sweep details, so a reader who only
    /// browsed lists kept stale ones indefinitely.
    @Test("A page write sweeps stale details too, and the reverse")
    func everyWriteSweepsBothTables() async throws {
        let store = try makeStore()
        await store.save(MovieDetails.fixture(id: 7), at: Self.beyondWindow)

        await store.save(Page.fixture(items: Movie.fixtures(count: 1)), for: MoviesQueryKey(.popular), at: Self.now)

        #expect(await store.details(for: 7) == nil)

        let stalePage = MoviesQueryKey(.search(.fixture("old")))
        await store.save(Page.fixture(items: Movie.fixtures(count: 1)), for: stalePage, at: Self.beyondWindow)

        await store.save(MovieDetails.fixture(id: 8), at: Self.now)

        #expect(await store.page(for: stalePage) == nil)
    }

    // MARK: - Factory

    /// Its own container per test: a shared one would let writes leak between
    /// cases the way the transport stubs once did.
    private func makeStore() throws -> MovieCacheStore {
        MovieCacheStore(modelContainer: try MovieCacheContainer.make(inMemory: true))
    }
}

extension MovieCacheStore {
    /// Counts rows the public surface deliberately cannot see, to prove a
    /// replaced page leaves nothing behind.
    func countOfCachedMovies() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<CachedMovie>())
    }

    func countOfCachedPages() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<CachedMoviePage>())
    }

    func countOfCachedDetails() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<CachedMovieDetails>())
    }
}
