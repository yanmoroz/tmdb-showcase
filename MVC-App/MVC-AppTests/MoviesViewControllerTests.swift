import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
@testable import MVC_App

@MainActor
@Suite("MoviesViewController")
final class MoviesViewControllerTests {
    /// Swift Testing builds one suite instance per test, so `deinit` works as
    /// teardown: by then the test's own local references are gone.
    private weak var trackedSUT: MoviesViewController?
    private var trackedLocation: SourceLocation?

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The controller outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    @Test("A loaded page reaches the collection view")
    func showsLoadedPage() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 8), totalPages: 3)
        let (sut, _) = makeSUT(result: .success(page))

        sut.loadViewIfNeeded()

        // waitUntil records an issue on timeout, so reaching the count is the
        // assertion — repeating it below would only double-report one failure.
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 8 }
    }

    @Test("The first page is requested as page 1")
    func requestsFirstPage() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 4))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        let calls = await fetchMovies.calls
        #expect(calls == [MoviesCall(query: .popular, page: 1)])
    }

    @Test("A failure leaves the collection empty")
    func keepsCollectionEmptyOnFailure() async throws {
        let (sut, fetchMovies) = makeSUT(result: .failure(.regionRestricted))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 0)
    }

    @Test("Displaying a cell near the end loads the next page")
    func loadsNextPageNearEnd() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 20), totalPages: 5)
        let (sut, fetchMovies) = makeSUT(result: .success(page))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 20 }

        sut.simulateCellDisplayed(at: 19)
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 40 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.page) == [1, 2])
    }

    @Test("A retryable error offers a retry button")
    func offersRetryForRetryableError() async throws {
        let (sut, fetchMovies) = makeSUT(result: .failure(.network(.offline)))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }
        let configuration = try #require(sut.currentUnavailableConfiguration)

        #expect(configuration.button.title == "Retry")
        #expect(configuration.secondaryText == AppError.network(.offline).message)
    }

    @Test("A region block offers no retry button")
    func hidesRetryForRegionRestricted() async throws {
        let (sut, fetchMovies) = makeSUT(result: .failure(.regionRestricted))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }
        let configuration = try #require(sut.currentUnavailableConfiguration)

        // .regionRestricted is not isRetryable: without a VPN a retry returns
        // the same 403. `.empty()` always carries a button, so the title tells
        // an offered retry from an absent one.
        #expect(configuration.button.title == nil)
    }

    @Test("Cancellation does not leave the screen spinning forever")
    func escapesLoadingOnCancellation() async throws {
        let (sut, fetchMovies) = makeSUT(result: .failure(.cancelled))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }
        let configuration = try #require(sut.currentUnavailableConfiguration)

        // The .loading spinner has no exit of its own: leaving the state
        // untouched on cancellation strands the user on it forever.
        #expect(configuration.text == "Couldn't load")
        #expect(configuration.button.title == "Retry")
    }

    @Test("Nothing is requested past the last page")
    func stopsAtLastPage() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 6), totalPages: 1)
        let (sut, fetchMovies) = makeSUT(result: .success(page))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 6 }

        for _ in 0..<3 {
            sut.simulateCellDisplayed(at: 5)
        }
        await drainPendingWork()

        let calls = await fetchMovies.calls
        #expect(calls.map(\.page) == [1])
        #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 6)
    }

    // MARK: - Search

    @Test("Typed text reaches the domain as a search query")
    func typedTextBecomesSearchQuery() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch("dune")
        try await waitUntil { await fetchMovies.calls.count == 2 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [.popular, .search(.fixture("dune"))])
    }

    @Test("Rapid typing collapses to one request with the last text")
    func rapidTypingCollapsesToLastQuery() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        // Three keystrokes in a row: the intermediate queries must not be sent.
        for text in ["d", "du", "dune"] {
            sut.simulateSearch(text)
        }
        await drainPendingWork()
        try await waitUntil { await fetchMovies.calls.count == 2 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [.popular, .search(.fixture("dune"))])
    }

    @Test("Blank input never becomes a search request", arguments: ["", "   ", "\n\t"])
    func blankInputStaysOnPopular(input: String) async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch(input)
        await drainPendingWork()

        // SearchText rejects blank input, and .popular is already on screen —
        // repeating the same query is pointless.
        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [.popular])
    }

    @Test("Clearing the field returns to popular")
    func clearingSearchReturnsToPopular() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch("dune")
        try await waitUntil { await fetchMovies.calls.count == 2 }

        sut.simulateSearch("")
        try await waitUntil { await fetchMovies.calls.count == 3 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [.popular, .search(.fixture("dune")), .popular])
    }

    @Test("Retyping the same text does not reload")
    func repeatingSameTextDoesNotReload() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch("dune")
        try await waitUntil { await fetchMovies.calls.count == 2 }

        // Trimming whitespace yields the same SearchText, hence the same MoviesQuery.
        sut.simulateSearch("  dune  ")
        await drainPendingWork()

        let calls = await fetchMovies.calls
        #expect(calls.count == 2)
    }

    @Test("Empty search results show the first-party state")
    func emptySearchShowsSearchConfiguration() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: [])))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch("qqqqzzz")
        try await waitUntil { await fetchMovies.calls.count == 2 }
        let configuration = try #require(sut.currentUnavailableConfiguration)

        // .search() writes its own text; our "No movies" would be a lie here.
        #expect(configuration.text != "No movies")
        #expect(configuration.text != nil)
    }

    // MARK: - Filter

    @Test("Choosing a genre produces a discover query")
    func genreProducesDiscoverQuery() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.applyFilter(MoviesFilter(genreID: 28))
        try await waitUntil { await fetchMovies.calls.count == 2 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [
            .popular,
            .discover(genreID: 28, sortedBy: .popularityDescending),
        ])
    }

    @Test("Clearing the genre under the default sort returns to popular")
    func clearingGenreReturnsToPopular() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.applyFilter(MoviesFilter(genreID: 28))
        try await waitUntil { await fetchMovies.calls.count == 2 }

        // Not .discover(nil, .popularityDescending): the same result, but a
        // needless request to a different endpoint.
        sut.applyFilter(MoviesFilter())
        try await waitUntil { await fetchMovies.calls.count == 3 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query).last == .popular)
    }

    @Test("Sorting without a genre still goes to discover")
    func sortWithoutGenreUsesDiscover() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.applyFilter(MoviesFilter(genreID: nil, sort: .ratingDescending))
        try await waitUntil { await fetchMovies.calls.count == 2 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query).last == .discover(genreID: nil, sortedBy: .ratingDescending))
    }

    @Test("The filter survives a search")
    func filterSurvivesSearch() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.applyFilter(MoviesFilter(genreID: 28))
        try await waitUntil { await fetchMovies.calls.count == 2 }

        sut.simulateSearch("dune")
        try await waitUntil { await fetchMovies.calls.count == 3 }

        // Clearing the field returns to the chosen genre, not to popular.
        sut.simulateSearch("")
        try await waitUntil { await fetchMovies.calls.count == 4 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [
            .popular,
            .discover(genreID: 28, sortedBy: .popularityDescending),
            .search(.fixture("dune")),
            .discover(genreID: 28, sortedBy: .popularityDescending),
        ])
    }

    @Test("The filter button is disabled during a search")
    func filterIsDisabledWhileSearching() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }
        #expect(sut.navigationItem.rightBarButtonItem?.isEnabled == true)

        // The domain forbids combining .search and .discover, so the filter must
        // not be configurable mid-search: the typed text would vanish silently.
        sut.simulateSearch("dune")
        try await waitUntil { await fetchMovies.calls.count == 2 }
        #expect(sut.navigationItem.rightBarButtonItem?.isEnabled == false)

        sut.simulateSearch("")
        try await waitUntil { await fetchMovies.calls.count == 3 }
        #expect(sut.navigationItem.rightBarButtonItem?.isEnabled == true)
    }

    @Test("The filter button is disabled before the debounce fires")
    func disablesFilterBeforeDebounceFires() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        // Deliberately no suspension point after the input: the debounced task
        // cannot have run, so this only passes if enablement follows the field.
        sut.simulateSearch("dune")
        #expect(sut.navigationItem.rightBarButtonItem?.isEnabled == false)
    }

    // MARK: - Source

    @Test("Choosing Trending asks for the trending feed")
    func trendingSourceProducesTrendingQuery() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSourceSelection(.trending)
        try await waitUntil { await fetchMovies.calls.count == 2 }

        #expect(await fetchMovies.calls.map(\.query).last == .trending(.week))
    }

    /// The same property that makes a filter survive a search: the source is a
    /// value on the filter, so switching away and back does not forget it.
    @Test("A genre survives a detour through Trending")
    func genreSurvivesTrending() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.applyFilter(MoviesFilter(genreID: 28))
        try await waitUntil { await fetchMovies.calls.count == 2 }

        sut.simulateSourceSelection(.trending)
        try await waitUntil { await fetchMovies.calls.count == 3 }

        sut.simulateSourceSelection(.catalogue)
        try await waitUntil { await fetchMovies.calls.count == 4 }

        #expect(await fetchMovies.calls.map(\.query) == [
            .popular,
            .discover(genreID: 28, sortedBy: .popularityDescending),
            .trending(.week),
            .discover(genreID: 28, sortedBy: .popularityDescending),
        ])
    }

    /// `/trending` accepts neither `with_genres` nor `sort_by`, so the sheet that
    /// sets them has nothing to offer — the same reason a search disables it.
    @Test("Trending leaves the filter sheet nothing to set")
    func disablesFilterUnderTrending() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }
        #expect(sut.navigationItem.rightBarButtonItem?.isEnabled == true)

        sut.simulateSourceSelection(.trending)
        #expect(sut.navigationItem.rightBarButtonItem?.isEnabled == false)

        sut.simulateSourceSelection(.catalogue)
        #expect(sut.navigationItem.rightBarButtonItem?.isEnabled == true)
    }

    @Test("A search overrides the source, so the control is disabled too")
    func disablesSourceControlWhileSearching() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch("dune")
        #expect(sut.testSourceControl.isEnabled == false)

        sut.simulateSearch("")
        #expect(sut.testSourceControl.isEnabled == true)
    }

    // MARK: - Details

    @Test("Selecting a movie pushes its details")
    func pushesDetailsOnSelection() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 3))
        let (sut, _) = makeSUT(result: .success(page))
        let navigation = UINavigationController(rootViewController: sut)

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 3 }

        sut.simulateSelection(at: 1)

        #expect(navigation.viewControllers.count == 2)
        #expect(navigation.topViewController is MovieDetailsViewController)
        await drainPendingWork()
    }

    /// The push form of the guard on `presentFilter`: two quick taps must not
    /// stack two copies of the same screen.
    @Test("A second selection does not stack another details screen")
    func doesNotStackDetails() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 3))
        let (sut, _) = makeSUT(result: .success(page))
        let navigation = UINavigationController(rootViewController: sut)

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 3 }

        sut.simulateSelection(at: 0)
        sut.simulateSelection(at: 2)

        #expect(navigation.viewControllers.count == 2)
        await drainPendingWork()
    }

    // MARK: - Offline signals

    /// With the cache wired, a warm page 1 answers offline silently, so this
    /// toast is what is left to tell the reader the network is gone. It had no
    /// coverage at all before.
    @Test("A failed later page toasts over the loaded list")
    func toastsWhenALaterPageFails() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 20), totalPages: 5)
        let (sut, fetchMovies) = makeSUT(result: .success(page))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 20 }

        await fetchMovies.setResult(.failure(.network(.offline)))
        sut.simulateCellDisplayed(at: 19)
        try await waitUntil { sut.view.firstSubview(of: ToastView.self) != nil }

        // The list survives the failure, and nothing covers it.
        #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 20)
        #expect(sut.currentUnavailableConfiguration == nil)
    }

    @Test("A cancelled later page says nothing")
    func staysSilentWhenALaterPageIsCancelled() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 20), totalPages: 5)
        let (sut, fetchMovies) = makeSUT(result: .success(page))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 20 }

        await fetchMovies.setResult(.failure(.cancelled))
        sut.simulateCellDisplayed(at: 19)
        try await waitUntil { await fetchMovies.calls.count == 2 }
        await drainPendingWork()

        // A superseded request is not news.
        #expect(sut.view.firstSubview(of: ToastView.self) == nil)
    }

    // MARK: - Factory

    /// The view is deliberately not loaded here: `loadViewIfNeeded()` starts
    /// the request, and that "act" step belongs in the test body.
    ///
    /// The controller holds a `Task` and targets `UIRefreshControl`, so a
    /// retain cycle is easy to introduce — hence the leak tracking.
    private func makeSUT(
        result: Result<Page<Movie>, AppError>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (sut: MoviesViewController, fetchMovies: FetchMoviesStub) {
        let fetchMovies = FetchMoviesStub(result: result)
        let sut = MoviesViewController(
            fetchMovies: fetchMovies,
            fetchGenres: FetchGenresStub(),
            fetchMovieDetails: FetchMovieDetailsStub(),
            imageURLBuilder: MovieImageURLBuilderStub(),
            // Zero interval keeps the debounce observable without waiting on
            // wall-clock: draining the main actor is enough to let it fire.
            searchDebounce: .zero
        )
        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchMovies)
    }
}

// MARK: - Scaffolding the controller cannot be touched without

@MainActor
private extension MoviesViewController {
    var testCollectionView: UICollectionView {
        guard let collectionView = view.firstSubview(of: UICollectionView.self) else {
            preconditionFailure("MoviesViewController stopped containing a UICollectionView")
        }
        return collectionView
    }

    /// UIKit rebuilds the configuration lazily, at a layout pass that never
    /// happens in a windowless test.
    ///
    /// The `autoreleasepool` is required: layout autoreleases objects holding
    /// the controller, and without draining the pool the leak check reads a
    /// deferred release as a retain cycle.
    var currentUnavailableConfiguration: UIContentUnavailableConfiguration? {
        autoreleasepool {
            setNeedsUpdateContentUnavailableConfiguration()
            view.layoutIfNeeded()
        }
        return contentUnavailableConfiguration as? UIContentUnavailableConfiguration
    }

    func simulateSearch(_ text: String) {
        guard let searchController = navigationItem.searchController else {
            preconditionFailure("MoviesViewController stopped installing a UISearchController")
        }
        searchController.searchBar.text = text
        updateSearchResults(for: searchController)
    }

    var testSourceControl: UISegmentedControl {
        autoreleasepool {
            guard let control = navigationItem.titleView as? UISegmentedControl else {
                preconditionFailure("MoviesViewController stopped showing a source control")
            }
            return control
        }
    }

    func simulateSourceSelection(_ source: MoviesFilter.Source) {
        autoreleasepool {
            guard let index = MoviesFilter.Source.allCases.firstIndex(of: source) else { return }
            let control = testSourceControl
            control.selectedSegmentIndex = index
            control.sendActions(for: .valueChanged)
        }
    }

    func simulateSelection(at item: Int) {
        autoreleasepool {
            collectionView(testCollectionView, didSelectItemAt: IndexPath(item: item, section: 0))
        }
    }

    func simulateCellDisplayed(at item: Int) {
        collectionView(
            testCollectionView,
            willDisplay: UICollectionViewCell(),
            forItemAt: IndexPath(item: item, section: 0)
        )
    }
}
