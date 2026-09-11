import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import VIPER_App

@MainActor
@Suite("MovieDetailsInteractor")
final class MovieDetailsInteractorTests {
    private weak var trackedSUT: MovieDetailsInteractor?
    private var trackedLocation: SourceLocation?

    private let output = MovieDetailsInteractorOutputSpy()
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

    @Test("Loaded details are reported")
    func reportsLoadedDetails() async throws {
        let (sut, _) = makeSUT(result: .success(.fixture(id: 42)))

        sut.loadDetails(for: 42)

        try await waitUntil { self.output.events == [.loaded(id: 42)] }
    }

    @Test("The request carries the id it was given")
    func requestsTheGivenID() async throws {
        let (sut, fetchDetails) = makeSUT()

        sut.loadDetails(for: 42)

        try await waitUntil { await fetchDetails.calls == [MovieDetailsCall(id: 42)] }
    }

    @Test("A failure is reported as the domain error")
    func reportsFailure() async throws {
        let (sut, _) = makeSUT(result: .failure(.network(.offline)))

        sut.loadDetails(for: 1)

        try await waitUntil { self.output.events == [.failedToLoad(.network(.offline))] }
    }

    /// The presenter shows the status until it hears back, so a cancellation
    /// nobody asked for still has to be reported.
    @Test("A cancelled request that was not replaced is still reported")
    func reportsUnrequestedCancellation() async throws {
        let (sut, _) = makeSUT(result: .failure(.cancelled))

        sut.loadDetails(for: 1)

        try await waitUntil { self.output.events == [.failedToLoad(.cancelled)] }
    }

    @Test("Starting a load abandons the one in flight")
    func abandonsTheLoadInFlight() async throws {
        let (sut, fetchDetails) = makeSUT()

        sut.loadDetails(for: 1)
        sut.loadDetails(for: 1)

        try await waitUntil { await fetchDetails.calls.count == 2 }
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
        await addToWatchlist.setResult(.failure(.storage))
        let (sut, _) = makeSUT()

        sut.setSaved(true, for: .fixture(id: 7))

        try await waitUntil { self.output.events == [.failedToSetSaved(true, 7, .storage)] }
    }

    // MARK: - Helpers

    private func makeSUT(
        result: Result<MovieDetails, AppError> = .success(.fixture()),
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (MovieDetailsInteractor, FetchMovieDetailsStub) {
        let fetchDetails = FetchMovieDetailsStub(result: result)
        let sut = MovieDetailsInteractor(
            fetchDetails: fetchDetails,
            fetchWatchlistIDs: fetchWatchlistIDs,
            addToWatchlist: addToWatchlist,
            removeFromWatchlist: removeFromWatchlist
        )
        sut.output = output

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchDetails)
    }
}

/// Records what the interactor reported, in order.
@MainActor
final class MovieDetailsInteractorOutputSpy: MovieDetailsInteractorOutput {
    enum Event: Equatable {
        case loaded(id: Movie.ID)
        case failedToLoad(AppError)
        case loadedSavedIDs(Set<Movie.ID>)
        case failedToSetSaved(Bool, Movie.ID, AppError)
    }

    private(set) var events: [Event] = []

    func didLoadDetails(_ details: MovieDetails) {
        events.append(.loaded(id: details.id))
    }

    func didFailToLoadDetails(with error: AppError) {
        events.append(.failedToLoad(error))
    }

    func didLoadSavedIDs(_ ids: Set<Movie.ID>) {
        events.append(.loadedSavedIDs(ids))
    }

    func didFailToSetSaved(_ isSaved: Bool, for id: Movie.ID, with error: AppError) {
        events.append(.failedToSetSaved(isSaved, id, error))
    }
}
