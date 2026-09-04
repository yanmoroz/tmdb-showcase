import Testing
import DomainKit
import DomainKitTestSupport

@Suite("AddToWatchlist")
struct AddToWatchlistTests {
    @Test("The whole film reaches the repository, not just its identifier")
    func passesMovie() async throws {
        let movie = Movie.fixture(id: 42, title: "Dune")
        let repository = WatchlistRepositoryStub()
        let addToWatchlist = AddToWatchlist(repository: repository)

        try await addToWatchlist(movie)

        await #expect(repository.saveCalls == [movie])
    }

    @Test("A failed save is propagated rather than swallowed")
    func propagatesError() async {
        let repository = WatchlistRepositoryStub(saveResult: .failure(.storage))
        let addToWatchlist = AddToWatchlist(repository: repository)

        await #expect(throws: AppError.storage) {
            try await addToWatchlist(.fixture())
        }
    }
}
