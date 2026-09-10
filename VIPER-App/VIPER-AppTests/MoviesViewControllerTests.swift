import Testing
import UIKit
import PresentationKit
@testable import VIPER_App

/// The controller's whole job is honouring ``MoviesView`` and reporting what the
/// reader does. These stand a real collection view up to check both directions;
/// everything about *what* to show is in `MoviesPresenterTests`.
@MainActor
@Suite("MoviesViewController")
final class MoviesViewControllerTests {
    /// `nonisolated(unsafe)`: `deinit` runs off the main actor, and loading a weak
    /// reference is safe from any thread. `isolated deinit` would silence the
    /// warning too, but it runs once the test is over, so a leak fails no test.
    nonisolated(unsafe) private weak var trackedSUT: MoviesViewController?
    private var trackedLocation: SourceLocation?

    private let presenter = MoviesViewOutputSpy()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The controller outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    // MARK: - Commands

    @Test("Shown films become cells")
    func showProducesCells() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.show(models(count: 8))

            #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 8)
        }
    }

    @Test("A cell carries what the presenter put in it")
    func cellRendersItsModel() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.show(models(count: 3))

            let cell = sut.collectionView(
                sut.testCollectionView,
                cellForItemAt: IndexPath(item: 1, section: 0)
            )

            #expect(cell is MovieCell)
        }
    }

    @Test("Updating one item does not disturb the rest")
    func updateItemReplacesOneModel() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.show(models(count: 4))

            sut.updateItem(at: 2, with: model(title: "Saved", isSaved: true))

            #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 4)
        }
    }

    @Test("An out-of-range update is ignored rather than trapping")
    func updateItemOutOfRangeIsIgnored() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.show(models(count: 2))

            sut.updateItem(at: 9, with: model(title: "Nowhere", isSaved: true))

            #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 2)
        }
    }

    @Test("A retryable failure draws a button")
    func failureOffersRetry() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showFailure("Nope", retry: true)

            #expect(sut.currentUnavailableConfiguration?.button.title == "Retry")
        }
    }

    @Test("An unfixable failure draws none")
    func failureWithoutRetryHasNoButton() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showFailure("Nope", retry: false)

            // `.empty()` always carries a button, so the title is what tells an
            // offered retry from an absent one.
            #expect(sut.currentUnavailableConfiguration?.button.title == nil)
        }
    }

    @Test("Hiding the overlay clears it")
    func hideOverlayClearsConfiguration() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.showLoading()

            sut.hideOverlay()

            #expect(sut.currentUnavailableConfiguration == nil)
        }
    }

    @Test("Disabled inputs reach the controls")
    func inputAvailabilityReachesTheControls() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.setInputsEnabled(source: false, filter: false)

            #expect(!sut.testSourceControl.isEnabled)
            #expect(sut.navigationItem.rightBarButtonItem?.isEnabled == false)
        }
    }

    @Test("A toast lands in the hierarchy")
    func toastIsShown() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showToast("Could not reach the server.")

            #expect(sut.view.firstSubview(of: ToastView.self) != nil)
        }
    }

    @Test("Nothing on screen is not item zero")
    func lastVisibleItemIsNilWhenEmpty() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            #expect(sut.lastVisibleItem() == nil)
        }
    }

    // MARK: - Reports

    @Test("Loading the view is reported")
    func loadingIsReported() {
        autoreleasepool {
            let sut = makeSUT()

            sut.loadViewIfNeeded()

            #expect(presenter.events.contains(.viewDidLoad))
        }
    }

    @Test("Selecting a film reports its position")
    func selectionIsReported() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.show(models(count: 3))

            sut.collectionView(sut.testCollectionView, didSelectItemAt: IndexPath(item: 1, section: 0))

            #expect(presenter.events.last == .didSelectItem(1))
        }
    }

    @Test("A cell's bookmark reports its position")
    func bookmarkIsReported() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.show(models(count: 3))

            let cell = sut.collectionView(
                sut.testCollectionView,
                cellForItemAt: IndexPath(item: 2, section: 0)
            ) as? MovieCell
            cell?.onToggleWatchlist?()

            #expect(presenter.events.last == .didToggleWatchlist(2))
        }
    }

    // MARK: - Helpers

    private func makeSUT(sourceLocation: SourceLocation = #_sourceLocation) -> MoviesViewController {
        let sut = MoviesViewController(presenter: presenter)

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

/// Records what the controller reported.
@MainActor
final class MoviesViewOutputSpy: MoviesViewOutput {
    enum Event: Equatable {
        case viewDidLoad
        case viewWillAppear
        case searchTextChanged(String)
        case didChangeSource(MoviesFilter.Source)
        case didTapFilter
        case didPullToRefresh
        case didTapRetry
        case willDisplayItem(Int)
        case didSelectItem(Int)
        case didToggleWatchlist(Int)
    }

    private(set) var events: [Event] = []

    func viewDidLoad() { events.append(.viewDidLoad) }
    func viewWillAppear() { events.append(.viewWillAppear) }

    func searchTextChanged(_ text: String) { events.append(.searchTextChanged(text)) }
    func didChangeSource(_ source: MoviesFilter.Source) { events.append(.didChangeSource(source)) }
    func didTapFilter() { events.append(.didTapFilter) }
    func didPullToRefresh() { events.append(.didPullToRefresh) }
    func didTapRetry() { events.append(.didTapRetry) }

    func willDisplayItem(at index: Int) { events.append(.willDisplayItem(index)) }
    func didSelectItem(at index: Int) { events.append(.didSelectItem(index)) }
    func didToggleWatchlist(at index: Int) { events.append(.didToggleWatchlist(index)) }
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
