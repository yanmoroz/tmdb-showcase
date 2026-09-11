import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import VIPER_App

private typealias SavedChange = WatchlistInteractorSpy.SavedChange

/// With the interactor faked, every test here is synchronous: a test plays the
/// interactor's part by calling the output methods itself.
@MainActor
@Suite("WatchlistPresenter")
final class WatchlistPresenterTests {
    private weak var trackedSUT: WatchlistPresenter?
    private var trackedLocation: SourceLocation?

    private let view = WatchlistViewSpy()
    private let interactor = WatchlistInteractorSpy()
    private let router = WatchlistRouterSpy()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The presenter outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    // MARK: - Loading

    @Test("Saved films reach the view in the order the store gave them")
    func showsSavedMovies() {
        let movies = Movie.fixtures(count: 3).reversed().map { $0 }
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didLoadWatchlist(movies)

        // Newest-first is the store's guarantee; the presenter must not re-sort.
        #expect(view.items.map(\.title) == movies.map(\.title))
    }

    @Test("Everything listed is shown as saved")
    func everythingIsMarkedSaved() {
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didLoadWatchlist(Movie.fixtures(count: 3))

        #expect(view.items.count == 3)
        #expect(view.items.allSatisfy { $0.isSaved })
    }

    @Test("Loading shows while the list is in flight")
    func showsLoadingWhileInFlight() {
        let sut = makeSUT()

        sut.viewWillAppear()

        #expect(interactor.loadCount == 1)
        #expect(view.overlay == .loading)
    }

    @Test("An empty watchlist explains itself")
    func showsEmptyState() {
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didLoadWatchlist([])

        #expect(view.overlay == .empty)
    }

    @Test("A failure offers Retry, and retrying re-reads")
    func retryRefetches() {
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didFailToLoadWatchlist(with: .storage)
        #expect(view.overlay == .failure(AppError.storage.message, retry: true))

        sut.didTapRetry()

        #expect(interactor.loadCount == 2)
        #expect(view.overlay == .loading)
    }

    @Test("Returning to the tab re-reads the list")
    func reloadsOnEveryAppearance() {
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didLoadWatchlist(Movie.fixtures(count: 1))
        sut.viewWillAppear()
        sut.didLoadWatchlist(Movie.fixtures(count: 4))

        #expect(interactor.loadCount == 2)
        #expect(view.items.count == 4)
    }

    // MARK: - Un-saving

    @Test("Un-saving empties the mark but keeps the row")
    func keepsTheRowAfterUnsaving() throws {
        let movies = Movie.fixtures(count: 3)
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didLoadWatchlist(movies)
        sut.didToggleWatchlist(at: 1)

        try #require(view.items.count == 3)
        #expect(view.items[1].isSaved == false)
        #expect(interactor.savedChanges == [SavedChange(isSaved: false, movie: movies[1])])
    }

    @Test("Tapping an un-saved row saves it again")
    func reSavesAfterUnsaving() throws {
        let movies = Movie.fixtures(count: 3)
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didLoadWatchlist(movies)
        sut.didToggleWatchlist(at: 1)
        sut.didToggleWatchlist(at: 1)

        // `#require`, not `#expect`: indexing a row that went missing would trap
        // and take every test still running down with it.
        try #require(view.items.count == 3)
        #expect(view.items[1].isSaved)
        #expect(interactor.savedChanges == [
            SavedChange(isSaved: false, movie: movies[1]),
            SavedChange(isSaved: true, movie: movies[1]),
        ])
    }

    @Test("A failed removal puts the mark back and says so")
    func rollsBackFailedRemoval() {
        let movies = Movie.fixtures(count: 2)
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didLoadWatchlist(movies)
        sut.didToggleWatchlist(at: 0)
        sut.didFailToSetSaved(false, for: movies[0].id, with: .storage)

        #expect(view.items[0].isSaved)
        #expect(view.toasts == [AppError.storage.message])
    }

    // MARK: - Routing

    @Test("Selecting a film asks the router to show it")
    func routesToDetails() {
        let movies = Movie.fixtures(count: 3)
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didLoadWatchlist(movies)
        sut.didSelectItem(at: 2)

        #expect(router.shownDetails == [movies[2]])
    }

    @Test("An out-of-range tap is ignored rather than trapping")
    func ignoresOutOfRangeTaps() {
        let sut = makeSUT()

        sut.viewWillAppear()
        sut.didLoadWatchlist(Movie.fixtures(count: 2))
        sut.didSelectItem(at: 9)
        sut.didToggleWatchlist(at: 9)

        #expect(router.shownDetails.isEmpty)
        #expect(interactor.savedChanges.isEmpty)
        #expect(view.items.allSatisfy { $0.isSaved })
    }

    // MARK: - Helpers

    private func makeSUT(sourceLocation: SourceLocation = #_sourceLocation) -> WatchlistPresenter {
        let sut = WatchlistPresenter(
            interactor: interactor,
            router: router,
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        sut.view = view

        trackedSUT = sut
        trackedLocation = sourceLocation
        return sut
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
}

/// Records what the presenter asked for and answers nothing: the tests play the
/// interactor's output themselves.
@MainActor
final class WatchlistInteractorSpy: WatchlistInteractorInput {
    struct SavedChange: Equatable {
        let isSaved: Bool
        let movie: Movie
    }

    private(set) var loadCount = 0
    private(set) var savedChanges: [SavedChange] = []

    func loadWatchlist() {
        loadCount += 1
    }

    func setSaved(_ isSaved: Bool, for movie: Movie) {
        savedChanges.append(SavedChange(isSaved: isSaved, movie: movie))
    }
}

/// Records where the presenter asked to go.
@MainActor
final class WatchlistRouterSpy: WatchlistRouterInput {
    private(set) var shownDetails: [Movie] = []

    func showDetails(for movie: Movie) {
        shownDetails.append(movie)
    }
}
