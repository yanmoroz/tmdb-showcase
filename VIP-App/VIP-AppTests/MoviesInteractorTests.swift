import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import VIP_App

@MainActor
@Suite("MoviesInteractor")
final class MoviesInteractorTests {
    private weak var trackedSUT: MoviesInteractor?
    private var trackedLocation: SourceLocation?

    private let watchlistIDs = FetchWatchlistIDsStub()
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

    @Test("A loaded page reaches the presenter")
    func presentsLoadedPage() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 8), totalPages: 3)
        let (sut, presenter, _) = makeSUT(result: .success(page))

        sut.start(.init())

        try await waitUntil { presenter.movies.count == 8 }
    }

    @Test("The first page is requested as page 1")
    func requestsFirstPage() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 4))))

        sut.start(.init())
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        #expect(await fetchMovies.calls == [MoviesCall(query: .popular, page: 1)])
    }

    @Test("The first page in flight is reported as loading over nothing")
    func reportsLoadingBeforeFirstPage() async throws {
        let (sut, presenter, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 4))))

        sut.start(.init())

        #expect(presenter.overlays.contains(.init(activity: .loading, isEmpty: true, isSearching: false)))
        try await waitUntil { presenter.movies.count == 4 }
    }

    @Test("A failed first page is reported with nothing loaded")
    func reportsFailureWithEmptyFeed() async throws {
        let (sut, presenter, _) = makeSUT(result: .failure(.regionRestricted))

        sut.start(.init())
        try await waitUntil { presenter.overlay?.activity == .failed(.regionRestricted) }

        #expect(presenter.movies.isEmpty)
        #expect(presenter.overlay == .init(activity: .failed(.regionRestricted), isEmpty: true, isSearching: false))
    }

    @Test("A cancelled first page is still a failure, not an idle empty screen")
    func reportsCancelledFirstPageAsFailure() async throws {
        let (sut, presenter, _) = makeSUT(result: .failure(.cancelled))

        sut.start(.init())

        try await waitUntil { presenter.overlay?.activity == .failed(.cancelled) }
    }

    @Test("Reloading asks again")
    func reloadRefetches() async throws {
        let (sut, presenter, fetchMovies) = makeSUT(result: .failure(.network(.offline)))

        sut.start(.init())
        try await waitUntil { presenter.overlay?.activity == .failed(.network(.offline)) }

        await fetchMovies.setResult(.success(.fixture(items: Movie.fixtures(count: 3))))
        sut.reload(.init())

        try await waitUntil { presenter.movies.count == 3 }
    }

    @Test("An empty catalogue is reported as empty")
    func reportsEmptyCatalogue() async throws {
        let (sut, presenter, _) = makeSUT(result: .success(.fixture(items: [], totalPages: 0)))

        sut.start(.init())

        try await waitUntil { presenter.overlay == .init(activity: .idle, isEmpty: true, isSearching: false) }
    }

    // MARK: - Pagination

    @Test("Displaying a cell near the end loads the next page")
    func loadsNextPageNearEnd() async throws {
        let (sut, presenter, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        )

        sut.start(.init())
        try await waitUntil { presenter.movies.count == 20 }

        await fetchMovies.setResult(
            .success(.fixture(items: Movie.fixtures(count: 20, startingAt: 21), page: 2, totalPages: 3))
        )
        sut.willDisplayItem(.init(index: 15))

        try await waitUntil { presenter.movies.count == 40 }
        #expect(await fetchMovies.calls.map(\.page) == [1, 2])
    }

    @Test("Nothing is requested past the last page")
    func stopsAtTheLastPage() async throws {
        let (sut, presenter, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 6), totalPages: 1))
        )

        sut.start(.init())
        try await waitUntil { presenter.movies.count == 6 }

        sut.willDisplayItem(.init(index: 5))
        await drainPendingWork()

        #expect(await fetchMovies.calls.count == 1)
    }

    // MARK: - Search

    @Test("Typed text reaches the domain as a search query")
    func searchesForTypedText() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.changeSearchText(.init(text: "dune"))

        try await waitUntil { await fetchMovies.calls.map(\.query).contains(.search(.fixture("dune"))) }
    }

    @Test("Rapid typing collapses to one request with the last text")
    func debouncesTyping() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        for input in ["d", "du", "dun", "dune"] {
            sut.changeSearchText(.init(text: input))
        }

        try await waitUntil { await fetchMovies.calls.map(\.query).contains(.search(.fixture("dune"))) }

        let searches = await fetchMovies.calls.map(\.query).filter { if case .search = $0 { true } else { false } }
        #expect(searches == [.search(.fixture("dune"))])
    }

    @Test("Blank input never becomes a search request", arguments: ["", "   ", "\n\t"])
    func ignoresBlankInput(input: String) async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.changeSearchText(.init(text: input))
        await drainPendingWork()

        let queries = await fetchMovies.calls.map(\.query)
        #expect(queries.allSatisfy { if case .search = $0 { false } else { true } })
    }

    @Test("Clearing the field returns to popular")
    func clearingSearchRestoresPopular() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.changeSearchText(.init(text: "dune"))
        try await waitUntil { await fetchMovies.calls.map(\.query).contains(.search(.fixture("dune"))) }

        sut.changeSearchText(.init(text: ""))
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .popular }
    }

    @Test("Retyping the same text does not reload")
    func identicalQueryDoesNotReload() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.changeSearchText(.init(text: "dune"))
        try await waitUntil { await fetchMovies.calls.count == 2 }

        sut.changeSearchText(.init(text: "dune"))
        await drainPendingWork()

        #expect(await fetchMovies.calls.count == 2)
    }

    @Test("Empty search results are reported as an empty search")
    func reportsEmptySearch() async throws {
        let (sut, presenter, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        try await waitUntil { presenter.movies.count == 2 }

        await fetchMovies.setResult(.success(.fixture(items: [], totalPages: 0)))
        sut.changeSearchText(.init(text: "zzzz"))

        try await waitUntil { presenter.overlay == .init(activity: .idle, isEmpty: true, isSearching: true) }
    }

    // MARK: - Filter

    @Test("Choosing a genre produces a discover query")
    func filtersByGenre() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.applyFilter(.init(filter: MoviesFilter(genreID: 28)))

        try await waitUntil {
            await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending)
        }
    }

    @Test("The filter survives a search")
    func filterOutlivesSearch() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.applyFilter(.init(filter: MoviesFilter(genreID: 28)))
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending) }

        sut.changeSearchText(.init(text: "dune"))
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .search(.fixture("dune")) }

        sut.changeSearchText(.init(text: ""))
        try await waitUntil {
            await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending)
        }
    }

    @Test("The data store holds what is currently set, for the sheet to open with")
    func storesCurrentFilter() {
        let (sut, _, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.applyFilter(.init(filter: MoviesFilter(genreID: 28, sort: .ratingDescending)))

        #expect(sut.filter == MoviesFilter(genreID: 28, sort: .ratingDescending))
    }

    @Test("Choosing Trending asks for the trending feed")
    func switchesToTrending() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.changeSource(.init(source: .trending))

        try await waitUntil { await fetchMovies.calls.map(\.query).last == .trending(.week) }
    }

    @Test("A genre survives a detour through Trending")
    func genreOutlivesTrending() async throws {
        let (sut, _, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.applyFilter(.init(filter: MoviesFilter(genreID: 28)))
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending) }

        sut.changeSource(.init(source: .trending))
        try await waitUntil { await fetchMovies.calls.map(\.query).last == .trending(.week) }

        sut.changeSource(.init(source: .catalogue))
        try await waitUntil {
            await fetchMovies.calls.map(\.query).last == .discover(genreID: 28, sortedBy: .popularityDescending)
        }
    }

    // MARK: - Input availability

    @Test("Starting reports what the controls may do")
    func startReportsInputAvailability() {
        let (sut, presenter, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())

        #expect(presenter.inputAvailability == .init(hasSearchText: false, allowsRefinement: true))
    }

    @Test("Typed text is reported on the keystroke, not on the debounce")
    func reportsTypedTextBeforeTheDebounceFires() {
        // The interval only has to outlast these synchronous assertions — holding
        // a pending timer past the end of the test would defer the interactor's
        // deallocation and trip the retain check in `deinit`.
        let (sut, presenter, _) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 2))),
            searchDebounce: .milliseconds(200)
        )

        sut.start(.init())
        sut.changeSearchText(.init(text: "dune"))

        #expect(presenter.inputAvailability == .init(hasSearchText: true, allowsRefinement: true))
    }

    @Test("Trending is reported as leaving nothing to refine")
    func trendingReportsNoRefinement() {
        let (sut, presenter, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 2))))

        sut.start(.init())
        sut.changeSource(.init(source: .trending))

        #expect(presenter.inputAvailability == .init(hasSearchText: false, allowsRefinement: false))
    }

    // MARK: - Watchlist

    @Test("A bookmark marks the film at once and saves it")
    func savesToWatchlist() async throws {
        let movies = Movie.fixtures(count: 3)
        let (sut, presenter, _) = makeSUT(result: .success(.fixture(items: movies)))

        sut.start(.init())
        try await waitUntil { presenter.movies.count == 3 }

        sut.toggleWatchlist(.init(index: 1))

        #expect(presenter.items == [.init(index: 1, movie: movies[1], isSaved: true)])
        try await waitUntil { await self.addToWatchlist.calls == [movies[1]] }
    }

    @Test("Bookmarking a saved film unmarks it and removes it")
    func removesFromWatchlist() async throws {
        let movies = Movie.fixtures(count: 3)
        await watchlistIDs.setResult(.success([movies[1].id]))
        let (sut, presenter, _) = makeSUT(result: .success(.fixture(items: movies)))

        sut.start(.init())
        sut.reloadSavedIDs(.init())
        try await waitUntil { presenter.movies.count == 3 && presenter.savedIDs == [movies[1].id] }

        sut.toggleWatchlist(.init(index: 1))

        #expect(presenter.items == [.init(index: 1, movie: movies[1], isSaved: false)])
        try await waitUntil { await self.removeFromWatchlist.calls == [movies[1].id] }
    }

    @Test("A failed save takes the mark back and reports why")
    func rollsBackFailedSave() async throws {
        await addToWatchlist.setResult(.failure(.storage))
        let (sut, presenter, _) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.start(.init())
        try await waitUntil { presenter.movies.count == 3 }

        sut.toggleWatchlist(.init(index: 0))

        try await waitUntil { presenter.items.count == 2 }
        #expect(presenter.items.map(\.isSaved) == [true, false])
        #expect(presenter.writeFailures == [.storage])
    }

    @Test("Returning to the list re-reads what is saved")
    func reloadsSavedIDs() async throws {
        let movies = Movie.fixtures(count: 3)
        let (sut, presenter, _) = makeSUT(result: .success(.fixture(items: movies)))

        sut.start(.init())
        try await waitUntil { presenter.movies.count == 3 }
        #expect(presenter.savedIDs.isEmpty)

        await watchlistIDs.setResult(.success([movies[2].id]))
        sut.reloadSavedIDs(.init())

        try await waitUntil { presenter.savedIDs == [movies[2].id] }
    }

    // MARK: - Selection

    /// The router reads the data store as soon as the selection is displayed, so
    /// the film has to be stored before it is reported.
    @Test("A selected film is in the data store by the time it is reported")
    func storesSelectionBeforeReportingIt() async throws {
        let movies = Movie.fixtures(count: 3)
        let (sut, presenter, _) = makeSUT(result: .success(.fixture(items: movies)))
        var storedWhenReported: Movie?
        presenter.onMovieSelection = { [weak sut] in
            storedWhenReported = sut?.selectedMovie
        }

        sut.start(.init())
        try await waitUntil { presenter.movies.count == 3 }

        sut.selectMovie(.init(index: 2))

        #expect(storedWhenReported == movies[2])
    }

    // MARK: - Later pages

    @Test("A failed later page is reported over the loaded list")
    func reportsLaterPageFailure() async throws {
        let (sut, presenter, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 3))
        )

        sut.start(.init())
        try await waitUntil { presenter.movies.count == 20 }

        await fetchMovies.setResult(.failure(.network(.offline)))
        sut.willDisplayItem(.init(index: 19))

        try await waitUntil { !presenter.laterPageFailures.isEmpty }
        #expect(presenter.laterPageFailures == [.network(.offline)])
        #expect(presenter.movies.count == 20)
        #expect(presenter.overlay == .init(activity: .idle, isEmpty: false, isSearching: false))
    }

    @Test("Pulling to refresh ends the control even when the request fails")
    func endsRefreshingOnFailure() async throws {
        let (sut, presenter, fetchMovies) = makeSUT(
            result: .success(.fixture(items: Movie.fixtures(count: 4)))
        )

        sut.start(.init())
        try await waitUntil { presenter.movies.count == 4 }

        await fetchMovies.setResult(.failure(.server(statusCode: 500)))
        sut.reload(.init())

        try await waitUntil { presenter.refreshEndedCount == 2 }
    }

    // MARK: - Helpers

    private func makeSUT(
        result: Result<Page<Movie>, AppError>,
        searchDebounce: Duration = .zero,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (MoviesInteractor, MoviesPresenterSpy, FetchMoviesStub) {
        let fetchMovies = FetchMoviesStub(result: result)
        let presenter = MoviesPresenterSpy()
        let sut = MoviesInteractor(
            presenter: presenter,
            fetchMovies: fetchMovies,
            fetchWatchlistIDs: watchlistIDs,
            addToWatchlist: addToWatchlist,
            removeFromWatchlist: removeFromWatchlist,
            searchDebounce: searchDebounce
        )

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, presenter, fetchMovies)
    }
}

/// Records what the interactor reported.
@MainActor
final class MoviesPresenterSpy: MoviesPresentationLogic {
    private(set) var movies: [Movie] = []
    private(set) var savedIDs: Set<Movie.ID> = []
    private(set) var items: [MoviesModels.Response.Item] = []
    private(set) var overlays: [MoviesModels.Response.Overlay] = []
    private(set) var laterPageFailures: [AppError] = []
    private(set) var writeFailures: [AppError] = []
    private(set) var inputAvailability: MoviesModels.Response.InputAvailability?
    private(set) var refreshEndedCount = 0

    /// Runs inside the report, where the router would read the data store.
    var onMovieSelection: (() -> Void)?

    var overlay: MoviesModels.Response.Overlay? { overlays.last }

    func presentFeed(_ response: MoviesModels.Response.Feed) {
        movies = response.movies
        savedIDs = response.savedIDs
    }

    func presentItem(_ response: MoviesModels.Response.Item) { items.append(response) }
    func presentOverlay(_ response: MoviesModels.Response.Overlay) { overlays.append(response) }

    func presentLaterPageFailure(_ response: MoviesModels.Response.Failure) { laterPageFailures.append(response.error) }
    func presentWriteFailure(_ response: MoviesModels.Response.Failure) { writeFailures.append(response.error) }
    func presentInputAvailability(_ response: MoviesModels.Response.InputAvailability) { inputAvailability = response }

    func presentRefreshEnded(_ response: MoviesModels.Response.RefreshEnded) { refreshEndedCount += 1 }
    func presentScrollToTop(_ response: MoviesModels.Response.ScrollToTop) {}
    func presentMovieSelection(_ response: MoviesModels.Response.MovieSelection) { onMovieSelection?() }
}
