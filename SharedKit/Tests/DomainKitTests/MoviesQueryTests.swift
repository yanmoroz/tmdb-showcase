import Testing
import DomainKit
import DomainKitTestSupport

@Suite("MoviesQuery")
struct MoviesQueryTests {
    // Equality and hashing are part of the contract: they discard a stale
    // load's result, and TCA keeps the query in State.

    @Test("Запросы с разными параметрами не равны")
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

    @Test("Запросы с одинаковыми параметрами совпадают и по значению, и по хешу")
    func equalQueriesShareHash() {
        let lhs = MoviesQuery.discover(genreID: 28, sortedBy: .ratingDescending)
        let rhs = MoviesQuery.discover(genreID: 28, sortedBy: .ratingDescending)

        #expect(lhs == rhs)
        #expect(Set([lhs, rhs]).count == 1)
    }

    @Test("Фильтр без выбранного жанра отличается от фильтра с жанром")
    func nilGenreIsDistinct() {
        #expect(
            MoviesQuery.discover(genreID: nil, sortedBy: .popularityDescending)
                != .discover(genreID: 28, sortedBy: .popularityDescending)
        )
    }
}
