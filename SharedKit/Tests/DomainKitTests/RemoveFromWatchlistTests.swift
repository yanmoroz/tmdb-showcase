import Testing
import DomainKit
import DomainKitTestSupport

@Suite("RemoveFromWatchlist")
struct RemoveFromWatchlistTests {
    @Test("The identifier reaches the repository")
    func passesIdentifier() async throws {
        let repository = WatchlistRepositoryStub()
        let removeFromWatchlist = RemoveFromWatchlist(repository: repository)

        try await removeFromWatchlist(id: 42)

        await #expect(repository.removeCalls == [42])
    }

    @Test("A failed removal is propagated rather than swallowed")
    func propagatesError() async {
        let repository = WatchlistRepositoryStub(removeResult: .failure(.storage))
        let removeFromWatchlist = RemoveFromWatchlist(repository: repository)

        await #expect(throws: AppError.storage) {
            try await removeFromWatchlist(id: 1)
        }
    }
}
