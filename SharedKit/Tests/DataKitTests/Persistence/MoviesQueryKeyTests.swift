import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("MoviesQueryKey")
struct MoviesQueryKeyTests {
    /// Literal expectations on purpose: a key assembled from `hashValue` could
    /// not satisfy them twice, and changing the format has to break a test
    /// rather than silently orphan every row already on disk.
    @Test("Each query case keeps its pinned key", arguments: [
        (MoviesQuery.popular, "popular"),
        (.trending(.day), "trending.day"),
        (.trending(.week), "trending.week"),
        (.search(.fixture("dune")), "search.dune"),
        (.discover(genreID: nil, sortedBy: .popularityDescending), "discover.genre=any.sort=popularity"),
        (.discover(genreID: 28, sortedBy: .ratingDescending), "discover.genre=28.sort=rating"),
        (.discover(genreID: 18, sortedBy: .releaseDateDescending), "discover.genre=18.sort=releaseDate"),
        (.discover(genreID: 35, sortedBy: .titleAscending), "discover.genre=35.sort=title"),
    ])
    func pinsKey(query: MoviesQuery, expected: String) {
        #expect(MoviesQueryKey(query).rawValue == expected)
    }

    @Test("Every sort option contributes its own token")
    func everySortOptionHasADistinctToken() {
        let keys = Set(
            MovieSortOption.allCases.map {
                MoviesQueryKey(.discover(genreID: nil, sortedBy: $0)).rawValue
            }
        )

        #expect(keys.count == MovieSortOption.allCases.count)
    }

    @Test("Every trending window contributes its own token")
    func everyTrendingWindowHasADistinctToken() {
        let keys = Set(
            TrendingWindow.allCases.map { MoviesQueryKey(.trending($0)).rawValue }
        )

        #expect(keys.count == TrendingWindow.allCases.count)
    }

    @Test("Different queries never share a key")
    func distinctQueriesGetDistinctKeys() {
        let queries: [MoviesQuery] = [
            .popular,
            .trending(.day),
            .trending(.week),
            // Probes the prefix hazard: this text is the name of another case.
            .search(.fixture("popular")),
            .search(.fixture("dune")),
            .discover(genreID: nil, sortedBy: .popularityDescending),
            .discover(genreID: 28, sortedBy: .popularityDescending),
            .discover(genreID: 28, sortedBy: .ratingDescending),
        ]

        let keys = Set(queries.map { MoviesQueryKey($0).rawValue })

        #expect(keys.count == queries.count)
    }

    @Test("Search keys inherit SearchText's normalisation rather than adding their own")
    func searchKeyFollowsSearchText() throws {
        let plain = try #require(SearchText("dune"))
        let padded = try #require(SearchText("  dune  "))
        let capitalised = try #require(SearchText("Dune"))

        #expect(MoviesQueryKey(.search(padded)) == MoviesQueryKey(.search(plain)))
        // Case is significant in the domain, so it has to be significant here.
        #expect(MoviesQueryKey(.search(capitalised)) != MoviesQueryKey(.search(plain)))
    }
}
