import Testing
import DomainKit
import DomainKitTestSupport

@Suite("MoviesQuery")
struct MoviesQueryTests {
    // Equality and hashing are part of the contract: they discard a stale
    // load's result, and TCA keeps the query in State.

    @Test("Queries with different parameters are not equal")
    func distinctQueriesDiffer() {
        #expect(MoviesQuery.popular != .trending(.day))
        #expect(MoviesQuery.trending(.day) != .trending(.week))
        #expect(MoviesQuery.search(.fixture("dune")) != .search(.fixture("Dune")))
        #expect(
            MoviesQuery.discover(genreID: 28, sortedBy: .popularityDescending)
                != .discover(genreID: 35, sortedBy: .popularityDescending)
        )
        #expect(
            MoviesQuery.discover(genreID: 28, sortedBy: .popularityDescending)
                != .discover(genreID: 28, sortedBy: .ratingDescending)
        )
    }

    @Test("Queries with identical parameters match by value and by hash")
    func equalQueriesShareHash() {
        let lhs = MoviesQuery.discover(genreID: 28, sortedBy: .ratingDescending)
        let rhs = MoviesQuery.discover(genreID: 28, sortedBy: .ratingDescending)

        #expect(lhs == rhs)
        #expect(Set([lhs, rhs]).count == 1)
    }

    @Test("A filter with no genre differs from one with a genre")
    func nilGenreIsDistinct() {
        #expect(
            MoviesQuery.discover(genreID: nil, sortedBy: .popularityDescending)
                != .discover(genreID: 28, sortedBy: .popularityDescending)
        )
    }
}
