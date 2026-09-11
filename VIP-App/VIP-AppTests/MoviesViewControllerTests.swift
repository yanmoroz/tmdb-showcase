import Testing
import UIKit
import PresentationKit
@testable import VIP_App

/// The controller's whole job is drawing what ``MoviesDisplayLogic`` hands it and
/// sending what the reader does. These stand a real collection view up to check
/// both directions; what to draw is in `MoviesPresenterTests`, what to do about
/// it in `MoviesInteractorTests`.
@MainActor
@Suite("MoviesViewController")
final class MoviesViewControllerTests {
    /// `nonisolated(unsafe)`: `deinit` runs off the main actor, and loading a weak
    /// reference is safe from any thread. `isolated deinit` would silence the
    /// warning too, but it runs once the test is over, so a leak fails no test.
    nonisolated(unsafe) private weak var trackedSUT: MoviesViewController?
    private var trackedLocation: SourceLocation?

    private let interactor = MoviesBusinessLogicSpy()
    private let router = MoviesRouterSpy()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The controller outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    // MARK: - Display

    @Test("Displayed films become cells")
    func feedProducesCells() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.displayFeed(.init(items: models(count: 8)))

            #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 8)
        }
    }

    @Test("A cell carries what the presenter put in it")
    func cellRendersItsModel() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.displayFeed(.init(items: models(count: 3)))

            let cell = sut.collectionView(
                sut.testCollectionView,
                cellForItemAt: IndexPath(item: 1, section: 0)
            )

            #expect(cell is MovieCell)
        }
    }

    @Test("Updating one item does not disturb the rest")
    func itemReplacesOneModel() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.displayFeed(.init(items: models(count: 4)))

            sut.displayItem(.init(index: 2, item: model(title: "Saved", isSaved: true)))

            #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 4)
        }
    }

    @Test("An out-of-range update is ignored rather than trapping")
    func itemOutOfRangeIsIgnored() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.displayFeed(.init(items: models(count: 2)))

            sut.displayItem(.init(index: 9, item: model(title: "Nowhere", isSaved: true)))

            #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 2)
        }
    }

    @Test("A retryable failure draws a button")
    func failureOffersRetry() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.displayOverlay(.failure(message: "Nope", retry: true))

            #expect(sut.currentUnavailableConfiguration?.button.title == "Retry")
        }
    }

    @Test("An unfixable failure draws none")
    func failureWithoutRetryHasNoButton() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.displayOverlay(.failure(message: "Nope", retry: false))

            // `.empty()` always carries a button, so the title is what tells an
            // offered retry from an absent one.
            #expect(sut.currentUnavailableConfiguration?.button.title == nil)
        }
    }

    @Test("A hidden overlay clears it")
    func hiddenOverlayClearsConfiguration() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.displayOverlay(.loading)

            sut.displayOverlay(.hidden)

            #expect(sut.currentUnavailableConfiguration == nil)
        }
    }

    @Test("Disabled inputs reach the controls")
    func inputAvailabilityReachesTheControls() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.displayInputAvailability(.init(sourceEnabled: false, filterEnabled: false))

            #expect(!sut.testSourceControl.isEnabled)
            #expect(sut.navigationItem.rightBarButtonItem?.isEnabled == false)
        }
    }

    @Test("A toast lands in the hierarchy")
    func toastIsShown() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.displayToast(.init(message: "Could not reach the server."))

            #expect(sut.view.firstSubview(of: ToastView.self) != nil)
        }
    }

    // MARK: - Pagination

    /// A reader already at the bottom sees no new cell when a page lands, so
    /// these cells, sent again, are all that can ask for the next one.
    @Test("A new feed sends the cells on screen again once laid out")
    func newFeedReSendsTheCellsOnScreen() throws {
        try autoreleasepool {
            let sut = makeSUT()
            sut.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            sut.displayFeed(.init(items: models(count: 20)))
            sut.view.layoutIfNeeded()
            let lastVisibleItem = try #require(sut.testCollectionView.indexPathsForVisibleItems.map(\.item).max())
            let sentBefore = interactor.requests.count

            sut.displayFeed(.init(items: models(count: 40)))
            sut.view.layoutIfNeeded()

            #expect(interactor.requests.dropFirst(sentBefore).contains(.willDisplayItem(lastVisibleItem)))
        }
    }

    // MARK: - Routing

    @Test("A displayed selection is routed")
    func selectionIsRouted() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.displayMovieSelection(.init())

            #expect(router.routeToDetailsCount == 1)
        }
    }

    // MARK: - Requests

    @Test("Loading the view starts the scene")
    func loadingStartsTheScene() {
        autoreleasepool {
            let sut = makeSUT()

            sut.loadViewIfNeeded()

            #expect(interactor.requests.contains(.start))
        }
    }

    @Test("Selecting a film sends its position")
    func selectionIsSent() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.displayFeed(.init(items: models(count: 3)))

            sut.collectionView(sut.testCollectionView, didSelectItemAt: IndexPath(item: 1, section: 0))

            #expect(interactor.requests.last == .selectMovie(1))
        }
    }

    @Test("A cell's bookmark sends its position")
    func bookmarkIsSent() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.displayFeed(.init(items: models(count: 3)))

            let cell = sut.collectionView(
                sut.testCollectionView,
                cellForItemAt: IndexPath(item: 2, section: 0)
            ) as? MovieCell
            cell?.onToggleWatchlist?()

            #expect(interactor.requests.last == .toggleWatchlist(2))
        }
    }

    // MARK: - Helpers

    private func makeSUT(sourceLocation: SourceLocation = #_sourceLocation) -> MoviesViewController {
        let sut = MoviesViewController(interactor: interactor, router: router)

        trackedSUT = sut
        trackedLocation = sourceLocation
        return sut
    }

    private func models(count: Int) -> [MovieCell.Model] {
        (0..<count).map { model(title: "Fixture \($0)", isSaved: false) }
    }

    private func model(title: String, isSaved: Bool) -> MovieCell.Model {
        MovieCell.Model(posterURL: nil, title: title, year: "2024", rating: "★ 7.5", isSaved: isSaved)
    }
}

/// Records what the controller sent.
@MainActor
final class MoviesBusinessLogicSpy: MoviesBusinessLogic {
    enum Request: Equatable {
        case start
        case reload
        case reloadSavedIDs
        case changeSearchText(String)
        case changeSource(MoviesFilter.Source)
        case applyFilter(MoviesFilter)
        case willDisplayItem(Int)
        case toggleWatchlist(Int)
        case selectMovie(Int)
    }

    private(set) var requests: [Request] = []

    func start(_ request: MoviesModels.Request.Start) { requests.append(.start) }
    func reload(_ request: MoviesModels.Request.Reload) { requests.append(.reload) }
    func reloadSavedIDs(_ request: MoviesModels.Request.ReloadSavedIDs) { requests.append(.reloadSavedIDs) }

    func changeSearchText(_ request: MoviesModels.Request.ChangeSearchText) { requests.append(.changeSearchText(request.text)) }
    func changeSource(_ request: MoviesModels.Request.ChangeSource) { requests.append(.changeSource(request.source)) }
    func applyFilter(_ request: MoviesModels.Request.ApplyFilter) { requests.append(.applyFilter(request.filter)) }

    func willDisplayItem(_ request: MoviesModels.Request.WillDisplayItem) { requests.append(.willDisplayItem(request.index)) }
    func toggleWatchlist(_ request: MoviesModels.Request.ToggleWatchlist) { requests.append(.toggleWatchlist(request.index)) }
    func selectMovie(_ request: MoviesModels.Request.SelectMovie) { requests.append(.selectMovie(request.index)) }
}

/// Records what the controller routed to.
@MainActor
final class MoviesRouterSpy: MoviesRoutingLogic {
    private(set) var routeToFilterCount = 0
    private(set) var routeToDetailsCount = 0

    func routeToFilter() { routeToFilterCount += 1 }
    func routeToDetails() { routeToDetailsCount += 1 }
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

    var testSourceControl: UISegmentedControl {
        autoreleasepool {
            guard let control = navigationItem.titleView as? UISegmentedControl else {
                preconditionFailure("MoviesViewController stopped showing a source control")
            }
            return control
        }
    }
}
