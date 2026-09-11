import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import VIP_App

@MainActor
@Suite("MoviesPresenter")
final class MoviesPresenterTests {
    private weak var trackedSUT: MoviesPresenter?
    private var trackedLocation: SourceLocation?

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The presenter outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    // MARK: - Overlay

    @Test("Loading over an empty list shows the spinner")
    func loadingOverNothing() {
        let (sut, view) = makeSUT()

        sut.presentOverlay(.init(activity: .loading, isEmpty: true, isSearching: false))

        #expect(view.overlays == [.loading])
    }

    @Test("Loading under a list covers nothing")
    func loadingUnderAList() {
        let (sut, view) = makeSUT()

        sut.presentOverlay(.init(activity: .loading, isEmpty: false, isSearching: false))

        #expect(view.overlays == [.hidden])
    }

    @Test("An empty catalogue says so")
    func emptyCatalogue() {
        let (sut, view) = makeSUT()

        sut.presentOverlay(.init(activity: .idle, isEmpty: true, isSearching: false))

        #expect(view.overlays == [.empty(isSearch: false)])
    }

    @Test("An empty search gets the first-party search state")
    func emptySearch() {
        let (sut, view) = makeSUT()

        sut.presentOverlay(.init(activity: .idle, isEmpty: true, isSearching: true))

        #expect(view.overlays == [.empty(isSearch: true)])
    }

    @Test("A loaded list covers nothing")
    func loadedList() {
        let (sut, view) = makeSUT()

        sut.presentOverlay(.init(activity: .idle, isEmpty: false, isSearching: false))

        #expect(view.overlays == [.hidden])
    }

    @Test(
        "A failure offers a retry only where retrying can help",
        arguments: [
            (AppError.regionRestricted, false),
            (AppError.network(.offline), true),
            (AppError.cancelled, true),
        ]
    )
    func failureOffersRetry(error: AppError, retry: Bool) {
        let (sut, view) = makeSUT()

        sut.presentOverlay(.init(activity: .failed(error), isEmpty: true, isSearching: false))

        #expect(view.overlays == [.failure(message: error.message, retry: retry)])
    }

    // MARK: - Failures

    @Test("A failed later page toasts")
    func laterPageFailureToasts() {
        let (sut, view) = makeSUT()

        sut.presentLaterPageFailure(.init(error: .network(.offline)))

        #expect(view.toasts == [AppError.network(.offline).message])
    }

    @Test("A cancelled later page says nothing")
    func cancelledLaterPageIsSilent() {
        let (sut, view) = makeSUT()

        sut.presentLaterPageFailure(.init(error: .cancelled))

        #expect(view.toasts.isEmpty)
    }

    @Test("A failed write toasts")
    func writeFailureToasts() {
        let (sut, view) = makeSUT()

        sut.presentWriteFailure(.init(error: .storage))

        #expect(view.toasts == [AppError.storage.message])
    }

    // MARK: - Input availability

    @Test("A search disables both controls")
    func searchDisablesBothControls() {
        let (sut, view) = makeSUT()

        sut.presentInputAvailability(.init(hasSearchText: true, allowsRefinement: true))

        #expect(view.inputAvailability == .init(sourceEnabled: false, filterEnabled: false))
    }

    @Test("Trending leaves the filter sheet nothing to set")
    func noRefinementDisablesTheFilter() {
        let (sut, view) = makeSUT()

        sut.presentInputAvailability(.init(hasSearchText: false, allowsRefinement: false))

        #expect(view.inputAvailability == .init(sourceEnabled: true, filterEnabled: false))
    }

    @Test("Nothing typed over a refinable feed leaves both controls live")
    func bothControlsLive() {
        let (sut, view) = makeSUT()

        sut.presentInputAvailability(.init(hasSearchText: false, allowsRefinement: true))

        #expect(view.inputAvailability == .init(sourceEnabled: true, filterEnabled: true))
    }

    // MARK: - Projection

    @Test("A film becomes a cell model")
    func filmBecomesACellModel() throws {
        let (sut, view) = makeSUT()
        let movie = Movie.fixture(id: 7, title: "Dune")

        sut.presentFeed(.init(movies: [movie], savedIDs: []))

        let item = try #require(view.items.first)
        #expect(view.items.count == 1)
        #expect(item.title == "Dune")
        #expect(item.posterURL == MovieImageURLBuilderStub().posterURL(path: movie.posterPath))
        #expect(item.year == MovieFormatting.year(movie.releaseDate))
        #expect(item.rating == MovieFormatting.rating(average: movie.voteAverage, count: movie.voteCount))
        #expect(!item.isSaved)
    }

    @Test("Saved films are marked from the saved IDs")
    func savedIDsMarkFilms() {
        let (sut, view) = makeSUT()
        let movies = Movie.fixtures(count: 3)

        sut.presentFeed(.init(movies: movies, savedIDs: [movies[1].id]))

        #expect(view.items.map(\.isSaved) == [false, true, false])
    }

    @Test("An item update keeps its position and carries its mark")
    func itemKeepsItsPosition() throws {
        let (sut, view) = makeSUT()

        sut.presentItem(.init(index: 1, movie: .fixture(id: 2, title: "Arrival"), isSaved: true))

        let update = try #require(view.updatedItems.first)
        #expect(view.updatedItems.count == 1)
        #expect(update.index == 1)
        #expect(update.item.title == "Arrival")
        #expect(update.item.isSaved)
    }

    // MARK: - Pass-through

    @Test("Refresh end, scroll to top and selection are passed straight on")
    func passesSignalsOn() {
        let (sut, view) = makeSUT()

        sut.presentRefreshEnded(.init())
        sut.presentScrollToTop(.init())
        sut.presentMovieSelection(.init())

        #expect(view.refreshEndedCount == 1)
        #expect(view.scrollToTopCount == 1)
        #expect(view.selectionCount == 1)
    }

    // MARK: - Helpers

    private func makeSUT(
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (MoviesPresenter, MoviesDisplayLogicSpy) {
        let view = MoviesDisplayLogicSpy()
        let sut = MoviesPresenter(imageURLBuilder: MovieImageURLBuilderStub())
        sut.viewController = view

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, view)
    }
}

/// Records what the presenter asked the screen to draw.
@MainActor
final class MoviesDisplayLogicSpy: MoviesDisplayLogic {
    private(set) var items: [MovieCell.Model] = []
    private(set) var updatedItems: [MoviesModels.ViewModel.Item] = []
    private(set) var overlays: [MoviesModels.ViewModel.Overlay] = []
    private(set) var toasts: [String] = []
    private(set) var inputAvailability: MoviesModels.ViewModel.InputAvailability?
    private(set) var refreshEndedCount = 0
    private(set) var scrollToTopCount = 0
    private(set) var selectionCount = 0

    func displayFeed(_ viewModel: MoviesModels.ViewModel.Feed) { items = viewModel.items }

    func displayItem(_ viewModel: MoviesModels.ViewModel.Item) { updatedItems.append(viewModel) }
    func displayOverlay(_ viewModel: MoviesModels.ViewModel.Overlay) { overlays.append(viewModel) }

    func displayToast(_ viewModel: MoviesModels.ViewModel.Toast) { toasts.append(viewModel.message) }
    func displayInputAvailability(_ viewModel: MoviesModels.ViewModel.InputAvailability) { inputAvailability = viewModel }

    func displayRefreshEnded(_ viewModel: MoviesModels.ViewModel.RefreshEnded) { refreshEndedCount += 1 }
    func displayScrollToTop(_ viewModel: MoviesModels.ViewModel.ScrollToTop) { scrollToTopCount += 1 }
    func displayMovieSelection(_ viewModel: MoviesModels.ViewModel.MovieSelection) { selectionCount += 1 }
}
