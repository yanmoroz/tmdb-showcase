import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import VIPER_App

@MainActor
@Suite("MoviesInteractor")
final class MoviesInteractorTests {
    private weak var trackedSUT: MoviesInteractor?
    private var trackedLocation: SourceLocation?

    private let output = MoviesInteractorOutputSpy()
    private let fetchWatchlistIDs = FetchWatchlistIDsStub()
    private let addToWatchlist = AddToWatchlistStub()
    private let removeFromWatchlist = RemoveFromWatchlistStub()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The interactor outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    // MARK: - Loading

    @Test("A loaded page is reported")
    func reportsLoadedPage() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 4), totalPages: 2)
        let (sut, _) = makeSUT(result: .success(page))

        sut.loadPage(1, of: .popular)

        try await waitUntil { self.output.events == [.loaded(page)] }
    }

    @Test("The request carries the page and the query it was given")
    func requestsWhatWasAsked() async throws {
        let (sut, fetchMovies) = makeSUT()

        sut.loadPage(2, of: .trending(.week))

        try await waitUntil { await fetchMovies.calls == [MoviesCall(query: .trending(.week), page: 2)] }
    }

    @Test("A failure is reported as the domain error")
    func reportsFailure() async throws {
        let (sut, _) = makeSUT(result: .failure(.network(.offline)))

        sut.loadPage(1, of: .popular)

        try await waitUntil { self.output.events == [.failedToLoad(.network(.offline))] }
    }

    /// The presenter shows loading until it hears back, so a cancellation nobody
    /// asked for — URLSession's, for instance — still has to be reported.
    @Test("A cancelled request that was not replaced is still reported")
    func reportsUnrequestedCancellation() async throws {
        let (sut, _) = makeSUT(result: .failure(.cancelled))

        sut.loadPage(1, of: .popular)

        try await waitUntil { self.output.events == [.failedToLoad(.cancelled)] }
    }

    /// The other half of the same contract: the presenter has already moved on,
    /// and an answer to the old question would land in the new feed.
    @Test("Starting a load abandons the one in flight")
    func abandonsTheLoadInFlight() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.loadPage(1, of: .popular)
        sut.loadPage(1, of: .trending(.week))

        try await waitUntil { await fetchMovies.calls.count == 2 }
        await drainPendingWork()

        #expect(output.events.count == 1)
    }

    // MARK: - Watchlist

    @Test("Saved IDs are reported")
    func reportsSavedIDs() async throws {
        await fetchWatchlistIDs.setResult(.success([1, 2]))
        let (sut, _) = makeSUT()

        sut.loadSavedIDs()

        try await waitUntil { self.output.events == [.loadedSavedIDs([1, 2])] }
    }

    @Test("A failed read of saved IDs reports nothing")
    func staysSilentOnFailedRead() async throws {
        await fetchWatchlistIDs.setResult(.failure(.storage))
        let (sut, _) = makeSUT()

        sut.loadSavedIDs()
        try await waitUntil { await self.fetchWatchlistIDs.callCount == 1 }
        await drainPendingWork()

        #expect(output.events.isEmpty)
    }

    @Test("Saving adds the film, and success reports nothing")
    func savesTheFilm() async throws {
        let movie = Movie.fixture(id: 7)
        let (sut, _) = makeSUT()

        sut.setSaved(true, for: movie)
        try await waitUntil { await self.addToWatchlist.calls == [movie] }
        await drainPendingWork()

        #expect(output.events.isEmpty)
    }

    @Test("Un-saving removes the film by its id")
    func removesTheFilm() async throws {
        let (sut, _) = makeSUT()

        sut.setSaved(false, for: .fixture(id: 7))

        try await waitUntil { await self.removeFromWatchlist.calls == [7] }
    }

    @Test("A failed write is reported with what was attempted")
    func reportsFailedWrite() async throws {
        await removeFromWatchlist.setResult(.failure(.storage))
        let (sut, _) = makeSUT()

        sut.setSaved(false, for: .fixture(id: 7))

        try await waitUntil { self.output.events == [.failedToSetSaved(false, 7, .storage)] }
    }

    // MARK: - Helpers

    private func makeSUT(
        result: Result<Page<Movie>, AppError> = .success(.empty()),
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (MoviesInteractor, FetchMoviesStub) {
        let fetchMovies = FetchMoviesStub(result: result)
        let sut = MoviesInteractor(
            fetchMovies: fetchMovies,
            fetchWatchlistIDs: fetchWatchlistIDs,
            addToWatchlist: addToWatchlist,
            removeFromWatchlist: removeFromWatchlist
        )
        sut.output = output

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchMovies)
    }
}

/// Records what the interactor reported, in order.
@MainActor
final class MoviesInteractorOutputSpy: MoviesInteractorOutput {
    enum Event: Equatable {
        case loaded(Page<Movie>)
        case failedToLoad(AppError)
        case loadedSavedIDs(Set<Movie.ID>)
        case failedToSetSaved(Bool, Movie.ID, AppError)
    }

    private(set) var events: [Event] = []

    func didLoad(_ page: Page<Movie>) {
        events.append(.loaded(page))
    }

    func didFailToLoad(with error: AppError) {
        events.append(.failedToLoad(error))
    }

    func didLoadSavedIDs(_ ids: Set<Movie.ID>) {
        events.append(.loadedSavedIDs(ids))
    }

    func didFailToSetSaved(_ isSaved: Bool, for id: Movie.ID, with error: AppError) {
        events.append(.failedToSetSaved(isSaved, id, error))
    }
}
