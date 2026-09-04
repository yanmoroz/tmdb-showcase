import Testing
import DomainKit
import DomainKitTestSupport

@Suite("FetchWatchlistIDs")
struct FetchWatchlistIDsTests {
    @Test("The identifiers come back untouched, in a single call")
    func returnsIdentifiers() async throws {
        let repository = WatchlistRepositoryStub(savedIdentifiersResult: .success([7, 42]))
        let fetchWatchlistIDs = FetchWatchlistIDs(repository: repository)

        let ids = try await fetchWatchlistIDs()

        #expect(ids == [7, 42])
        await #expect(repository.savedIdentifiersCallCount == 1)
    }

    @Test("A storage error is propagated")
    func propagatesError() async {
        let repository = WatchlistRepositoryStub(savedIdentifiersResult: .failure(.storage))
        let fetchWatchlistIDs = FetchWatchlistIDs(repository: repository)

        await #expect(throws: AppError.storage) {
            try await fetchWatchlistIDs()
        }
    }
}
