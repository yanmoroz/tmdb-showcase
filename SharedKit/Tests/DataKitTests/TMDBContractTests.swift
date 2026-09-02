import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

/// Checks that TMDB still answers the way the fixtures describe.
///
/// Fixtures pin yesterday's contract: if TMDB renames a field, drops an endpoint
/// or stops accepting a `sort_by` string, the hermetic tests stay green while the
/// app breaks. Only a live request catches that.
///
/// `.serialized` keeps five requests in a row from looking like a burst and
/// drawing a 429.
@Suite("TMDBContract", .requiresTMDBAccess, .serialized, .tags(.live))
struct TMDBContractTests {
    private var movies: TMDBMoviesRepository {
        TMDBMoviesRepository(configuration: LiveTMDB.configuration)
    }

    @Test("The list format and pagination wrapper have not changed")
    func popularStillDecodes() async throws {
        let page = try await movies.movies(query: .popular, page: 1)

        #expect(!page.items.isEmpty)
        #expect(page.page == 1)
        #expect(page.totalPages > 1)
        #expect(page.items.allSatisfy { !$0.title.isEmpty })
    }

    @Test("The sort_by strings are still accepted", arguments: MovieSortOption.allCases)
    func discoverAcceptsSortOption(option: MovieSortOption) async throws {
        // A stale string yields 422, which the classifier collapses into .unknown.
        let page = try await movies.movies(
            query: .discover(genreID: nil, sortedBy: option),
            page: 1
        )

        #expect(!page.items.isEmpty)
    }

    @Test("The details format has not changed")
    func detailsStillDecode() async throws {
        let details = try await movies.movieDetails(id: 550)

        #expect(details.title == "Fight Club")
        #expect(details.runtime != nil)
        #expect(!details.genres.isEmpty)
    }

    @Test("The genre catalogue is still there")
    func genresStillDecode() async throws {
        let repository = TMDBGenresRepository(configuration: LiveTMDB.configuration)

        let genres = try await repository.genres()

        #expect(genres.contains(Genre(id: 28, name: "Action")))
    }

    @Test("Search accepts the query parameter")
    func searchStillWorks() async throws {
        let page = try await movies.movies(query: .search(.fixture("dune")), page: 1)

        #expect(!page.items.isEmpty)
    }
}
