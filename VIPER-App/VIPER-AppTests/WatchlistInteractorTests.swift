import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import VIPER_App

@MainActor
@Suite("WatchlistInteractor")
final class WatchlistInteractorTests {
    private weak var trackedSUT: WatchlistInteractor?
    private var trackedLocation: SourceLocation?

    private let output = WatchlistInteractorOutputSpy()
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

    @Test("The saved films are reported in the store's order")
    func reportsSavedFilms() async throws {
        let movies = Movie.fixtures(count: 3).reversed().map { $0 }
        let (sut, _) = makeSUT(saved: .success(movies))

        sut.loadWatchlist()

        try await waitUntil { self.output.events == [.loaded(movies.map(\.id))] }
    }

    @Test("A failure is reported as the domain error")
    func reportsFailure() async throws {
        let (sut, _) = makeSUT(saved: .failure(.storage))

        sut.loadWatchlist()

        try await waitUntil { self.output.events == [.failedToLoad(.storage)] }
    }

    /// The presenter shows loading until it hears back, so a cancellation nobody
    /// asked for still has to be reported.
    @Test("A cancelled read that was not replaced is still reported")
    func reportsUnrequestedCancellation() async throws {
        let (sut, _) = makeSUT(saved: .failure(.cancelled))

        sut.loadWatchlist()

        try await waitUntil { self.output.events == [.failedToLoad(.cancelled)] }
    }

    @Test("Starting a load abandons the one in flight")
    func abandonsTheLoadInFlight() async throws {
        let (sut, fetchWatchlist) = makeSUT(saved: .success(Movie.fixtures(count: 2)))

        sut.loadWatchlist()
        sut.loadWatchlist()

        try await waitUntil { await fetchWatchlist.callCount == 2 }
        await drainPendingWork()

        #expect(output.events.count == 1)
    }

    // MARK: - Writes

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
        saved: Result<[Movie], AppError> = .success([]),
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (WatchlistInteractor, FetchWatchlistStub) {
        let fetchWatchlist = FetchWatchlistStub(result: saved)
        let sut = WatchlistInteractor(
            fetchWatchlist: fetchWatchlist,
            addToWatchlist: addToWatchlist,
            removeFromWatchlist: removeFromWatchlist
        )
        sut.output = output

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchWatchlist)
    }
}

/// Records what the interactor reported, in order.
@MainActor
final class WatchlistInteractorOutputSpy: WatchlistInteractorOutput {
    enum Event: Equatable {
        case loaded([Movie.ID])
        case failedToLoad(AppError)
        case failedToSetSaved(Bool, Movie.ID, AppError)
    }

    private(set) var events: [Event] = []

    func didLoadWatchlist(_ movies: [Movie]) {
        events.append(.loaded(movies.map(\.id)))
    }

    func didFailToLoadWatchlist(with error: AppError) {
        events.append(.failedToLoad(error))
    }

    func didFailToSetSaved(_ isSaved: Bool, for id: Movie.ID, with error: AppError) {
        events.append(.failedToSetSaved(isSaved, id, error))
    }
}
