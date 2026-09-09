import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import MVP_App

@MainActor
@Suite("WatchlistPresenter")
final class WatchlistPresenterTests {
    private weak var trackedSUT: WatchlistPresenter?
    private var trackedLocation: SourceLocation?

    private let addToWatchlist = AddToWatchlistStub()
    private let removeFromWatchlist = RemoveFromWatchlistStub()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The presenter outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    @Test("Saved films reach the view in the order the store gave them")
    func showsSavedMovies() async throws {
        let movies = Movie.fixtures(count: 3).reversed().map { $0 }
        let (sut, view, _) = makeSUT(saved: .success(movies))

        sut.viewWillAppear()
        try await waitUntil { view.items.count == 3 }

        // Newest-first is the store's guarantee; the presenter must not re-sort.
        #expect(view.items.map(\.title) == movies.map(\.title))
    }

    @Test("Everything listed is shown as saved")
    func everythingIsMarkedSaved() async throws {
        let (sut, view, _) = makeSUT(saved: .success(Movie.fixtures(count: 3)))

        sut.viewWillAppear()
        try await waitUntil { view.items.count == 3 }

        #expect(view.items.allSatisfy { $0.isSaved })
    }

    @Test("An empty watchlist explains itself")
    func showsEmptyState() async throws {
        let (sut, view, _) = makeSUT(saved: .success([]))

        sut.viewWillAppear()
        try await waitUntil { view.overlay == .empty }
    }

    @Test("A failure offers Retry, and retrying re-reads")
    func retryRefetches() async throws {
        let (sut, view, fetchWatchlist) = makeSUT(saved: .failure(.storage))

        sut.viewWillAppear()
        try await waitUntil { view.overlay == .failure(AppError.storage.message, retry: true) }

        await fetchWatchlist.setResult(.success(Movie.fixtures(count: 2)))
        sut.didTapRetry()

        try await waitUntil { view.items.count == 2 }
        #expect(await fetchWatchlist.callCount == 2)
    }

    @Test("Returning to the tab re-reads the list")
    func reloadsOnEveryAppearance() async throws {
        let (sut, view, fetchWatchlist) = makeSUT(saved: .success(Movie.fixtures(count: 1)))

        sut.viewWillAppear()
        try await waitUntil { view.items.count == 1 }

        await fetchWatchlist.setResult(.success(Movie.fixtures(count: 4)))
        sut.viewWillAppear()

        try await waitUntil { view.items.count == 4 }
    }

    @Test("Un-saving empties the mark but keeps the row")
    func keepsTheRowAfterUnsaving() async throws {
        let movies = Movie.fixtures(count: 3)
        let (sut, view, _) = makeSUT(saved: .success(movies))

        sut.viewWillAppear()
        try await waitUntil { view.items.count == 3 }

        sut.didToggleWatchlist(at: 1)

        #expect(view.items.count == 3)
        #expect(view.items[1].isSaved == false)
        try await waitUntil { await self.removeFromWatchlist.calls == [movies[1].id] }
    }

    @Test("Tapping an un-saved row saves it again")
    func reSavesAfterUnsaving() async throws {
        let movies = Movie.fixtures(count: 3)
        let (sut, view, _) = makeSUT(saved: .success(movies))

        sut.viewWillAppear()
        try await waitUntil { view.items.count == 3 }

        sut.didToggleWatchlist(at: 1)
        sut.didToggleWatchlist(at: 1)

        #expect(view.items[1].isSaved)
        try await waitUntil { await self.addToWatchlist.calls == [movies[1]] }
    }

    @Test("A failed removal puts the mark back and says so")
    func rollsBackFailedRemoval() async throws {
        await removeFromWatchlist.setResult(.failure(.storage))
        let (sut, view, _) = makeSUT(saved: .success(Movie.fixtures(count: 2)))

        sut.viewWillAppear()
        try await waitUntil { view.items.count == 2 }

        sut.didToggleWatchlist(at: 0)
        #expect(view.items[0].isSaved == false)

        try await waitUntil { !view.toasts.isEmpty }
        #expect(view.items[0].isSaved)
        #expect(view.toasts == [AppError.storage.message])
    }

    @Test("Selecting a film asks the view to show it")
    func showsDetails() async throws {
        let movies = Movie.fixtures(count: 3)
        let (sut, view, _) = makeSUT(saved: .success(movies))

        sut.viewWillAppear()
        try await waitUntil { view.items.count == 3 }

        sut.didSelectItem(at: 2)

        #expect(view.shownDetails == [movies[2]])
    }

    @Test("An out-of-range tap is ignored rather than trapping")
    func ignoresOutOfRangeTaps() async throws {
        let (sut, view, _) = makeSUT(saved: .success(Movie.fixtures(count: 2)))

        sut.viewWillAppear()
        try await waitUntil { view.items.count == 2 }

        sut.didSelectItem(at: 9)
        sut.didToggleWatchlist(at: 9)

        #expect(view.shownDetails.isEmpty)
        #expect(view.items.allSatisfy { $0.isSaved })
    }

    // MARK: - Helpers

    private func makeSUT(
        saved: Result<[Movie], AppError>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (WatchlistPresenter, WatchlistViewSpy, FetchWatchlistStub) {
        let fetchWatchlist = FetchWatchlistStub(result: saved)
        let view = WatchlistViewSpy()
        let sut = WatchlistPresenter(
            fetchWatchlist: fetchWatchlist,
            addToWatchlist: addToWatchlist,
            removeFromWatchlist: removeFromWatchlist,
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        sut.view = view

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, view, fetchWatchlist)
    }
}

/// Records what the presenter asked the watchlist screen to do.
@MainActor
final class WatchlistViewSpy: WatchlistView {
    enum Overlay: Equatable {
        case loading
        case empty
        case failure(String, retry: Bool)
        case none
    }

    private(set) var items: [MovieCell.Model] = []
    private(set) var overlay: Overlay = .none
    private(set) var toasts: [String] = []
    private(set) var shownDetails: [Movie] = []

    func show(_ movies: [MovieCell.Model]) {
        items = movies
    }

    func updateItem(at index: Int, with model: MovieCell.Model) {
        guard items.indices.contains(index) else { return }
        items[index] = model
    }

    func showLoading() { overlay = .loading }
    func showEmpty() { overlay = .empty }
    func showFailure(_ message: String, retry: Bool) { overlay = .failure(message, retry: retry) }
    func hideOverlay() { overlay = .none }

    func showToast(_ message: String) { toasts.append(message) }
    func showDetails(for movie: Movie) { shownDetails.append(movie) }
}
