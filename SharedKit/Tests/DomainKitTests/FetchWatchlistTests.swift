import Testing
import DomainKit
import DomainKitTestSupport

@Suite("FetchWatchlist")
struct FetchWatchlistTests {
    @Test("Saved films come back in the repository's order, in a single call")
    func returnsSavedMovies() async throws {
        let expected = Movie.fixtures(count: 3).reversed().map { $0 }
        let repository = WatchlistRepositoryStub(savedMoviesResult: .success(expected))
        let fetchWatchlist = FetchWatchlist(repository: repository)

        let movies = try await fetchWatchlist()

        // Newest-first is the store's guarantee, so the use case must not re-sort.
        #expect(movies == expected)
        await #expect(repository.savedMoviesCallCount == 1)
    }

    @Test("An empty watchlist is a result, not a failure")
    func returnsEmpty() async throws {
        let fetchWatchlist = FetchWatchlist(repository: WatchlistRepositoryStub())

        #expect(try await fetchWatchlist().isEmpty)
    }

    @Test("A storage error is propagated")
    func propagatesError() async {
        let repository = WatchlistRepositoryStub(savedMoviesResult: .failure(.storage))
        let fetchWatchlist = FetchWatchlist(repository: repository)

        await #expect(throws: AppError.storage) {
            try await fetchWatchlist()
        }
    }
}
