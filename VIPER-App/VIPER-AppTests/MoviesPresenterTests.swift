import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import VIPER_App

private typealias Load = MoviesInteractorSpy.Load
private typealias SavedChange = MoviesInteractorSpy.SavedChange

/// With the interactor faked, no request is ever in flight: a test plays the
/// interactor's part by calling the output methods itself. Only the search
/// debounce still has to be waited for.
@MainActor
@Suite("MoviesPresenter")
final class MoviesPresenterTests {
    private weak var trackedSUT: MoviesPresenter?
    private var trackedLocation: SourceLocation?

    private let view = MoviesViewSpy()
    private let interactor = MoviesInteractorSpy()
    private let router = MoviesRouterSpy()

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

    @Test("A loaded page reaches the view")
    func showsLoadedPage() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 8), totalPages: 3))

        #expect(view.items.count == 8)
    }

    @Test("The first page is requested as page 1 of popular")
    func requestsFirstPage() {
        let sut = makeSUT()

        sut.viewDidLoad()

        #expect(interactor.loads == [Load(page: 1, query: .popular)])
    }

    @Test("Loading shows while the first page is in flight")
    func showsLoadingBeforeFirstPage() {
        let sut = makeSUT()

        sut.viewDidLoad()

        #expect(view.overlay == .loading)
    }

    @Test("A failure shows nothing and reports itself")
    func showsFailureWithEmptyFeed() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didFailToLoad(with: .regionRestricted)

        #expect(view.items.isEmpty)
        #expect(view.overlay == .failure(AppError.regionRestricted.message, retry: false))
    }

    @Test("A retryable error offers a retry")
    func offersRetryForTransientFailures() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didFailToLoad(with: .network(.offline))

        #expect(view.overlay == .failure(AppError.network(.offline).message, retry: true))
    }

    @Test("Cancellation still offers a way out")
    func offersRetryAfterCancellation() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didFailToLoad(with: .cancelled)

        #expect(view.overlay == .failure(AppError.cancelled.message, retry: true))
    }

    @Test("Retrying asks again")
    func retryRefetches() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didFailToLoad(with: .network(.offline))
        sut.didTapRetry()

        #expect(interactor.loads == [Load(page: 1, query: .popular), Load(page: 1, query: .popular)])
    }

    @Test("An empty catalogue says so")
    func showsEmptyState() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: [], totalPages: 0))

        #expect(view.overlay == .empty(isSearch: false))
    }

    // MARK: - Pagination

    @Test("Displaying a cell near the end loads the next page")
    func loadsNextPageNearEnd() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        sut.willDisplayItem(at: 15)
        sut.didLoad(.fixture(items: Movie.fixtures(count: 20, startingAt: 21), page: 2, totalPages: 3))

        #expect(interactor.loads.map(\.page) == [1, 2])
        #expect(view.items.count == 40)
    }

    @Test("Nothing is requested past the last page")
    func stopsAtTheLastPage() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 6), totalPages: 1))
        sut.willDisplayItem(at: 5)

        #expect(interactor.loads.count == 1)
    }

    @Test("A page that lands under a full screen keeps paginating")
    func continuesWhenTheScreenIsStillFull() {
        let sut = makeSUT()
        // The reader is already at the bottom: willDisplay fired for these cells
        // while page 1 was in flight and found a load in progress.
        view.visibleItem = 19

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))

        // Nothing calls willDisplayItem here. The presenter has to ask the view
        // what is on screen once the page lands, or the list stalls at the
        // bottom with no cell left to trigger the next one.
        #expect(interactor.loads.map(\.page) == [1, 2])
        #expect(view.lastVisibleItemCalls > 0)
    }

    @Test("An empty screen does not pull the next page on its own")
    func doesNotPaginateWithNothingOnScreen() {
        let sut = makeSUT()
        view.visibleItem = nil

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))

        #expect(interactor.loads.count == 1)
    }

    // MARK: - The loading flag

    // The request lives in the interactor, so nothing but these keeps the
    // presenter's flag honest. The interactor's half is in MoviesInteractorTests.

    @Test("A page in flight is asked for once, however many cells appear")
    func asksForAPageOnce() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        for item in 14...19 {
            sut.willDisplayItem(at: item)
        }

        #expect(interactor.loads.map(\.page) == [1, 2])
    }

    @Test("A failed page frees the next request")
    func failureEndsTheLoad() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        sut.willDisplayItem(at: 19)
        sut.didFailToLoad(with: .network(.offline))
        sut.willDisplayItem(at: 19)

        #expect(interactor.loads.map(\.page) == [1, 2, 2])
    }

    @Test("A new question is asked at once, even with a page in flight")
    func newQueryDoesNotWaitForTheLoadInFlight() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didChangeSource(.trending)

        #expect(interactor.loads == [Load(page: 1, query: .popular), Load(page: 1, query: .trending(.week))])
    }

    // MARK: - Search

    @Test("Typed text reaches the interactor as a search query")
    func searchesForTypedText() async throws {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.searchTextChanged("dune")

        try await waitUntil { self.interactor.loads.last?.query == .search(.fixture("dune")) }
    }

    @Test("Rapid typing collapses to one request with the last text")
    func debouncesTyping() async throws {
        let sut = makeSUT()

        sut.viewDidLoad()
        for input in ["d", "du", "dun", "dune"] {
            sut.searchTextChanged(input)
        }
        try await waitUntil { self.interactor.loads.last?.query == .search(.fixture("dune")) }
        await drainPendingWork()

        let searches = interactor.loads.map(\.query).filter { if case .search = $0 { true } else { false } }
        #expect(searches == [.search(.fixture("dune"))])
    }

    @Test("Blank input never becomes a search request", arguments: ["", "   ", "\n\t"])
    func ignoresBlankInput(input: String) async {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.searchTextChanged(input)
        await drainPendingWork()

        #expect(interactor.loads.map(\.query).allSatisfy { if case .search = $0 { false } else { true } })
    }

    @Test("Clearing the field returns to popular")
    func clearingSearchRestoresPopular() async throws {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.searchTextChanged("dune")
        try await waitUntil { self.interactor.loads.last?.query == .search(.fixture("dune")) }

        sut.searchTextChanged("")
        try await waitUntil { self.interactor.loads.last?.query == .popular }
    }

    @Test("Retyping the same text does not reload")
    func identicalQueryDoesNotReload() async throws {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.searchTextChanged("dune")
        try await waitUntil { self.interactor.loads.count == 2 }

        sut.searchTextChanged("dune")
        await drainPendingWork()

        #expect(interactor.loads.count == 2)
    }

    @Test("Empty search results get the first-party search state")
    func showsSearchEmptyState() async throws {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 2)))
        sut.searchTextChanged("zzzz")
        try await waitUntil { self.interactor.loads.last?.query == .search(.fixture("zzzz")) }

        sut.didLoad(.fixture(items: [], totalPages: 0))

        #expect(view.overlay == .empty(isSearch: true))
    }

    // MARK: - Filter

    @Test("Choosing a genre asks for a discover query")
    func filtersByGenre() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didApplyFilter(MoviesFilter(genreID: 28))

        #expect(interactor.loads.last?.query == .discover(genreID: 28, sortedBy: .popularityDescending))
    }

    @Test("The filter survives a search")
    func filterOutlivesSearch() async throws {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didApplyFilter(MoviesFilter(genreID: 28))
        sut.searchTextChanged("dune")
        try await waitUntil { self.interactor.loads.last?.query == .search(.fixture("dune")) }

        sut.searchTextChanged("")
        try await waitUntil {
            self.interactor.loads.last?.query == .discover(genreID: 28, sortedBy: .popularityDescending)
        }
    }

    @Test("Tapping filter hands the router what is currently set")
    func routesToFilterWithCurrentSelection() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didApplyFilter(MoviesFilter(genreID: 28, sort: .ratingDescending))
        sut.didTapFilter()

        #expect(router.shownFilters == [MoviesFilter(genreID: 28, sort: .ratingDescending)])
        #expect(router.lastFilterOutput === sut)
    }

    @Test("Choosing Trending asks for the trending feed")
    func switchesToTrending() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didChangeSource(.trending)

        #expect(interactor.loads.last?.query == .trending(.week))
    }

    @Test("A genre survives a detour through Trending")
    func genreOutlivesTrending() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didApplyFilter(MoviesFilter(genreID: 28))
        sut.didChangeSource(.trending)
        sut.didChangeSource(.catalogue)

        let lastTwo = Array(interactor.loads.map(\.query).suffix(2))
        #expect(lastTwo == [.trending(.week), .discover(genreID: 28, sortedBy: .popularityDescending)])
    }

    // MARK: - Input availability

    @Test("A search disables both controls")
    func searchDisablesInputs() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.searchTextChanged("dune")

        #expect(!view.sourceEnabled)
        #expect(!view.filterEnabled)
    }

    @Test("The controls go dead on the keystroke, not on the debounce")
    func disablesInputsBeforeTheDebounceFires() {
        // The whole point: availability is read from the typed text, so there is
        // no window where the controls are live over a search about to start.
        // The interval only has to outlast these synchronous assertions.
        let sut = makeSUT(searchDebounce: .milliseconds(200))

        sut.viewDidLoad()
        sut.searchTextChanged("dune")

        #expect(!view.filterEnabled)
        #expect(!view.sourceEnabled)
        #expect(interactor.loads.count == 1)
    }

    @Test("Trending leaves the filter sheet nothing to set")
    func trendingDisablesFilter() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didChangeSource(.trending)

        #expect(view.sourceEnabled)
        #expect(!view.filterEnabled)
    }

    // MARK: - Watchlist

    @Test("A bookmark marks the film at once and asks to save it")
    func savesToWatchlist() {
        let movies = Movie.fixtures(count: 3)
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: movies))
        sut.didToggleWatchlist(at: 1)

        #expect(view.items[1].isSaved)
        #expect(interactor.savedChanges == [SavedChange(isSaved: true, movie: movies[1])])
    }

    @Test("Bookmarking a saved film asks to remove it")
    func removesFromWatchlist() {
        let movies = Movie.fixtures(count: 3)
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: movies))
        sut.didLoadSavedIDs([movies[1].id])
        sut.didToggleWatchlist(at: 1)

        #expect(!view.items[1].isSaved)
        #expect(interactor.savedChanges == [SavedChange(isSaved: false, movie: movies[1])])
    }

    @Test("A failed save puts the mark back and says so")
    func rollsBackFailedSave() {
        let movies = Movie.fixtures(count: 3)
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: movies))
        sut.didToggleWatchlist(at: 0)
        sut.didFailToSetSaved(true, for: movies[0].id, with: .storage)

        #expect(!view.items[0].isSaved)
        #expect(view.toasts == [AppError.storage.message])
    }

    @Test("Appearing re-reads what is saved")
    func reloadsWatchlistOnAppear() {
        let movies = Movie.fixtures(count: 3)
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: movies))
        sut.viewWillAppear()
        sut.didLoadSavedIDs([movies[2].id])

        #expect(interactor.savedIDsLoadCount == 1)
        #expect(view.items[2].isSaved)
    }

    // MARK: - Routing

    @Test("Selecting a film asks the router to show it")
    func routesToDetails() {
        let movies = Movie.fixtures(count: 3)
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: movies))
        sut.didSelectItem(at: 2)

        #expect(router.shownDetails == [movies[2]])
    }

    // MARK: - Later pages

    @Test("A failed later page toasts over the loaded list")
    func toastsOnLaterPageFailure() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        sut.willDisplayItem(at: 19)
        sut.didFailToLoad(with: .network(.offline))

        #expect(view.toasts == [AppError.network(.offline).message])
        #expect(view.items.count == 20)
        #expect(view.overlay == .none)
    }

    @Test("A cancelled later page says nothing")
    func staysSilentOnCancellation() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        sut.willDisplayItem(at: 19)
        sut.didFailToLoad(with: .cancelled)

        #expect(view.toasts.isEmpty)
        #expect(view.items.count == 20)
    }

    @Test("Pulling to refresh ends the control even when the request fails")
    func endsRefreshingOnFailure() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoad(.fixture(items: Movie.fixtures(count: 4)))
        sut.didPullToRefresh()
        sut.didFailToLoad(with: .server(statusCode: 500))

        #expect(view.endRefreshingCount == 2)
    }

    // MARK: - Helpers

    private func makeSUT(
        searchDebounce: Duration = .zero,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> MoviesPresenter {
        let sut = MoviesPresenter(
            interactor: interactor,
            router: router,
            imageURLBuilder: MovieImageURLBuilderStub(),
            searchDebounce: searchDebounce
        )
        sut.view = view

        trackedSUT = sut
        trackedLocation = sourceLocation
        return sut
    }
}

/// Records what the presenter asked for and answers nothing: the tests play the
/// interactor's output themselves.
@MainActor
final class MoviesInteractorSpy: MoviesInteractorInput {
    struct Load: Equatable {
        let page: Int
        let query: MoviesQuery
    }

    struct SavedChange: Equatable {
        let isSaved: Bool
        let movie: Movie
    }

    private(set) var loads: [Load] = []
    private(set) var savedIDsLoadCount = 0
    private(set) var savedChanges: [SavedChange] = []

    func loadPage(_ page: Int, of query: MoviesQuery) {
        loads.append(Load(page: page, query: query))
    }

    func loadSavedIDs() {
        savedIDsLoadCount += 1
    }

    func setSaved(_ isSaved: Bool, for movie: Movie) {
        savedChanges.append(SavedChange(isSaved: isSaved, movie: movie))
    }
}

/// Records where the presenter asked to go.
@MainActor
final class MoviesRouterSpy: MoviesRouterInput {
    private(set) var shownFilters: [MoviesFilter] = []
    /// `weak`: the output is the presenter under test, which holds this spy.
    private(set) weak var lastFilterOutput: (any MoviesFilterModuleOutput)?
    private(set) var shownDetails: [Movie] = []

    func showFilter(_ selection: MoviesFilter, output: any MoviesFilterModuleOutput) {
        shownFilters.append(selection)
        lastFilterOutput = output
    }

    func showDetails(for movie: Movie) {
        shownDetails.append(movie)
    }
}
