import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import MVP_App

@MainActor
@Suite("MoviesPresenter")
final class MoviesPresenterTests {
    private weak var trackedSUT: MoviesPresenter?
    private var trackedLocation: SourceLocation?

    private let watchlistIDs = FetchWatchlistIDsStub()
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

    // MARK: - Loading

    @Test("A loaded page reaches the view")
    func showsLoadedPage() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 8), totalPages: 3)
        let (sut, view, _) = makeSUT(result: .success(page))

        sut.viewDidLoad()

        try await waitUntil { view.items.count == 8 }
    }

    @Test("The first page is requested as page 1")
    func requestsFirstPage() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 4))))

        sut.viewDidLoad()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        #expect(await fetchMovies.calls == [MoviesCall(query: .popular, page: 1)])
    }

    @Test("Nothing is shown while the first page is in flight")
    func showsLoadingBeforeFirstPage() async throws {
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 4))))

        sut.viewDidLoad()

        #expect(view.overlays.contains(.loading))
        try await waitUntil { view.items.count == 4 }
    }

    @Test("A failure shows nothing and reports itself")
    func showsFailureWithEmptyFeed() async throws {
        let (sut, view, _) = makeSUT(result: .failure(.regionRestricted))

        sut.viewDidLoad()
        try await waitUntil { view.overlay != .loading }

        #expect(view.items.isEmpty)
        #expect(view.overlay == .failure(AppError.regionRestricted.message, retry: false))
    }

    @Test("A retryable error offers a retry")
    func offersRetryForTransientFailures() async throws {
        let (sut, view, _) = makeSUT(result: .failure(.network(.offline)))

        sut.viewDidLoad()
        try await waitUntil { view.overlay == .failure(AppError.network(.offline).message, retry: true) }
    }

    @Test("Cancellation still offers a way out")
    func offersRetryAfterCancellation() async throws {
        let (sut, view, _) = makeSUT(result: .failure(.cancelled))

        sut.viewDidLoad()
        try await waitUntil { view.overlay == .failure(AppError.cancelled.message, retry: true) }
    }

    @Test("Retrying asks again")
    func retryRefetches() async throws {
        let (sut, view, fetchMovies) = makeSUT(result: .failure(.network(.offline)))

        sut.viewDidLoad()
        try await waitUntil { view.overlay != .loading }

        await fetchMovies.setResult(.success(.fixture(items: Movie.fixtures(count: 3))))
        sut.didTapRetry()

        try await waitUntil { view.items.count == 3 }
    }

    @Test("An empty catalogue says so")
    func showsEmptyState() async throws {
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: [], totalPages: 0)))

        sut.viewDidLoad()
        try await waitUntil { view.overlay == .empty(isSearch: false) }
    }

    // MARK: - Pagination

    @Test("Displaying a cell near the end loads the next page")
    func loadsNextPageNearEnd() async throws {
        let (sut, view, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        )

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 20 }

        await fetchMovies.setResult(
            .success(.fixture(items: Movie.fixtures(count: 20, startingAt: 21), page: 2, totalPages: 3))
        )
        sut.willDisplayItem(at: 15)

        try await waitUntil { view.items.count == 40 }
        #expect(await fetchMovies.calls.map(\.page) == [1, 2])
    }

    @Test("Nothing is requested past the last page")
    func stopsAtTheLastPage() async throws {
        let (sut, view, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 6), totalPages: 1))
        )

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 6 }

        sut.willDisplayItem(at: 5)
        await drainPendingWork()

        #expect(await fetchMovies.calls.count == 1)
    }

    @Test("A page that lands under a full screen keeps paginating")
    func continuesWhenTheScreenIsStillFull() async throws {
        let (sut, view, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        )
        // The reader is already at the bottom: willDisplay fired for these cells
        // while page 1 was in flight and found a load in progress.
        view.visibleItem = 19

        sut.viewDidLoad()

        // Nothing calls willDisplayItem here. The presenter has to ask the view
        // what is on screen once the page lands, or the list stalls at the
        // bottom with no cell left to trigger the next one.
        try await waitUntil { await fetchMovies.calls.count >= 2 }
        #expect(view.lastVisibleItemCalls > 0)
    }

    @Test("An empty screen does not pull the next page on its own")
    func doesNotPaginateWithNothingOnScreen() async throws {
        let (sut, view, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        )
        view.visibleItem = nil

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 20 }
        await drainPendingWork()

        #expect(await fetchMovies.calls.count == 1)
    }

    // MARK: - Search

    @Test("Typed text reaches the domain as a search query")
    func searchesForTypedText() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.searchTextChanged("dune")

        try await waitUntil { await fetchMovies.calls.map(\.query).contains(.search(.fixture("dune"))) }
    }

    @Test("Rapid typing collapses to one request with the last text")
    func debouncesTyping() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        for input in ["d", "du", "dun", "dune"] {
            sut.searchTextChanged(input)
        }

        try await waitUntil { await fetchMovies.calls.map(\.query).contains(.search(.fixture("dune"))) }

        let searches = await fetchMovies.calls.map(\.query).filter { if case .search = $0 { true } else { false } }
        #expect(searches == [.search(.fixture("dune"))])
    }

    @Test("Blank input never becomes a search request", arguments: ["", "   ", "\n\t"])
    func ignoresBlankInput(input: String) async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.searchTextChanged(input)
        await drainPendingWork()

        let queries = await fetchMovies.calls.map(\.query)
        #expect(queries.allSatisfy { if case .search = $0 { false } else { true } })
    }

    @Test("Clearing the field returns to popular")
    func clearingSearchRestoresPopular() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.searchTextChanged("dune")
        try await waitUntil { await fetchMovies.calls.map(\.query).contains(.search(.fixture("dune"))) }

        sut.searchTextChanged("")
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .popular }
    }

    @Test("Retyping the same text does not reload")
    func identicalQueryDoesNotReload() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.searchTextChanged("dune")
        try await waitUntil { await fetchMovies.calls.count == 2 }

        sut.searchTextChanged("dune")
        await drainPendingWork()

        #expect(await fetchMovies.calls.count == 2)
    }

    @Test("Empty search results get the first-party search state")
    func showsSearchEmptyState() async throws {
        let (sut, view, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 2 }

        await fetchMovies.setResult(.success(.fixture(items: [], totalPages: 0)))
        sut.searchTextChanged("zzzz")

        try await waitUntil { view.overlay == .empty(isSearch: true) }
    }

    // MARK: - Filter

    @Test("Choosing a genre produces a discover query")
    func filtersByGenre() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.didApplyFilter(MoviesFilter(genreID: 28))

        try await waitUntil {
            await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending)
        }
    }

    @Test("The filter survives a search")
    func filterOutlivesSearch() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.didApplyFilter(MoviesFilter(genreID: 28))
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending) }

        sut.searchTextChanged("dune")
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .search(.fixture("dune")) }

        sut.searchTextChanged("")
        try await waitUntil {
            await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending)
        }
    }

    @Test("Tapping filter hands the sheet what is currently set")
    func showsFilterWithCurrentSelection() async throws {
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.didApplyFilter(MoviesFilter(genreID: 28, sort: .ratingDescending))
        sut.didTapFilter()

        #expect(view.shownFilter == MoviesFilter(genreID: 28, sort: .ratingDescending))
    }

    @Test("Choosing Trending asks for the trending feed")
    func switchesToTrending() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.didChangeSource(.trending)

        try await waitUntil { await fetchMovies.calls.map(\.query).last == .trending(.week) }
    }

    @Test("A genre survives a detour through Trending")
    func genreOutlivesTrending() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.didApplyFilter(MoviesFilter(genreID: 28))
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending) }

        sut.didChangeSource(.trending)
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .trending(.week) }

        sut.didChangeSource(.catalogue)
        try await waitUntil {
            await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending)
        }
    }

    // MARK: - Input availability

    @Test("A search disables both controls")
    func searchDisablesInputs() async throws {
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.searchTextChanged("dune")

        #expect(!view.sourceEnabled)
        #expect(!view.filterEnabled)
    }

    @Test("The controls go dead on the keystroke, not on the debounce")
    func disablesInputsBeforeTheDebounceFires() async throws {
        // The whole point: availability is read from the typed text, so there is
        // no window where the controls are live over a search about to start.
        // The interval only has to outlast these two synchronous assertions —
        // holding a pending timer past the end of the test would defer the
        // presenter's deallocation and trip the retain check in `deinit`.
        let (sut, view, _) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 2))),
            searchDebounce: .milliseconds(200)
        )

        sut.viewDidLoad()
        sut.searchTextChanged("dune")

        #expect(!view.filterEnabled)
        #expect(!view.sourceEnabled)
    }

    @Test("Trending leaves the filter sheet nothing to set")
    func trendingDisablesFilter() async throws {
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.viewDidLoad()
        sut.didChangeSource(.trending)

        #expect(view.sourceEnabled)
        #expect(!view.filterEnabled)
    }

    // MARK: - Watchlist

    @Test("A bookmark saves that film")
    func savesToWatchlist() async throws {
        let movies = Movie.fixtures(count: 3)
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: movies)))

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 3 }

        sut.didToggleWatchlist(at: 1)

        #expect(view.items[1].isSaved)
        try await waitUntil { await self.addToWatchlist.calls == [movies[1]] }
    }

    @Test("Bookmarking a saved film removes it")
    func removesFromWatchlist() async throws {
        let movies = Movie.fixtures(count: 3)
        await watchlistIDs.setResult(.success([movies[1].id]))
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: movies)))

        sut.viewDidLoad()
        sut.viewWillAppear()
        try await waitUntil { view.items.count == 3 && view.items[1].isSaved }

        sut.didToggleWatchlist(at: 1)

        #expect(!view.items[1].isSaved)
        try await waitUntil { await self.removeFromWatchlist.calls == [movies[1].id] }
    }

    @Test("A failed save puts the mark back and says so")
    func rollsBackFailedSave() async throws {
        await addToWatchlist.setResult(.failure(.storage))
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 3 }

        sut.didToggleWatchlist(at: 0)

        try await waitUntil { !view.items[0].isSaved }
        #expect(view.toasts == [AppError.storage.message])
    }

    @Test("Returning to the list re-reads what is saved")
    func reloadsWatchlistOnAppear() async throws {
        let movies = Movie.fixtures(count: 3)
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: movies)))

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 3 }
        #expect(!view.items[2].isSaved)

        await watchlistIDs.setResult(.success([movies[2].id]))
        sut.viewWillAppear()

        try await waitUntil { view.items[2].isSaved }
    }

    // MARK: - Routing

    @Test("Selecting a film asks the view to show it")
    func showsDetails() async throws {
        let movies = Movie.fixtures(count: 3)
        let (sut, view, _) = makeSUT(result: .success(.fixture(items: movies)))

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 3 }

        sut.didSelectItem(at: 2)

        #expect(view.shownDetails == [movies[2]])
    }

    // MARK: - Later pages

    @Test("A failed later page toasts over the loaded list")
    func toastsOnLaterPageFailure() async throws {
        let (sut, view, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        )

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 20 }

        await fetchMovies.setResult(.failure(.network(.offline)))
        sut.willDisplayItem(at: 19)

        try await waitUntil { !view.toasts.isEmpty }
        #expect(view.toasts == [AppError.network(.offline).message])
        #expect(view.items.count == 20)
        #expect(view.overlay == .none)
    }

    @Test("A cancelled later page says nothing")
    func staysSilentOnCancellation() async throws {
        let (sut, view, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        )

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 20 }

        await fetchMovies.setResult(.failure(.cancelled))
        sut.willDisplayItem(at: 19)
        await drainPendingWork()

        #expect(view.toasts.isEmpty)
        #expect(view.items.count == 20)
    }

    @Test("Pulling to refresh ends the control even when the request fails")
    func endsRefreshingOnFailure() async throws {
        let (sut, view, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 4)))
        )

        sut.viewDidLoad()
        try await waitUntil { view.items.count == 4 }

        await fetchMovies.setResult(.failure(.server(statusCode: 500)))
        sut.didPullToRefresh()

        try await waitUntil { view.endRefreshingCount == 2 }
    }

    // MARK: - Helpers

    private func makeSUT(
        result: Result<Page<Movie>, AppError>,
        searchDebounce: Duration = .zero,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (MoviesPresenter, MoviesViewSpy, FetchMoviesStub) {
        let fetchMovies = FetchMoviesStub(result: result)
        let view = MoviesViewSpy()
        let sut = MoviesPresenter(
            fetchMovies: fetchMovies,
            fetchWatchlistIDs: watchlistIDs,
            addToWatchlist: addToWatchlist,
            removeFromWatchlist: removeFromWatchlist,
            imageURLBuilder: MovieImageURLBuilderStub(),
            searchDebounce: searchDebounce
        )
        sut.view = view

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, view, fetchMovies)
    }
}
