import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import MVP_App

/// The controller's whole job is honouring ``MoviesView`` and reporting what the
/// reader does. These stand a real collection view up to check both directions;
/// everything about *what* to show is in `MoviesPresenterTests`, which needs no
/// `UIView` at all.
@MainActor
@Suite("MoviesViewController")
final class MoviesViewControllerTests {
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

    @Test("Selecting a film is reported, and the routing closure runs")
    func selectionReachesTheRouter() {
        autoreleasepool {
            let shown = Box<[Movie]>([])
            let movies = Movie.fixtures(count: 3)
            let sut = makeSUT(onShowDetails: { shown.value.append($0) })
            // showDetails guards on being the top view controller, so the stack has
            // to exist for the closure to be reached at all.
            _ = UINavigationController(rootViewController: sut)
            sut.loadViewIfNeeded()

            sut.showDetails(for: movies[1])

            #expect(shown.value == [movies[1]])
        }
    }

    @Test("Details are not pushed from a screen that is not on top")
    func selectionIsIgnoredOffTop() {
        autoreleasepool {
            let shown = Box<[Movie]>([])
            let sut = makeSUT(onShowDetails: { shown.value.append($0) })
            let navigation = UINavigationController(rootViewController: sut)
            navigation.pushViewController(UIViewController(), animated: false)
            sut.loadViewIfNeeded()

            sut.showDetails(for: .fixture())

            #expect(shown.value.isEmpty)
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        onShowDetails: @escaping (Movie) -> Void = { _ in },
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> MoviesViewController {
        // The destination itself is irrelevant here; what matters is whether the
        // controller reached for one.
        let destination = { (movie: Movie) -> UIViewController in
            onShowDetails(movie)
            return UIViewController()
        }
        let presenter = MoviesPresenter(
            fetchMovies: FetchMoviesStub(),
            fetchWatchlistIDs: FetchWatchlistIDsStub(),
            addToWatchlist: AddToWatchlistStub(),
            removeFromWatchlist: RemoveFromWatchlistStub(),
            imageURLBuilder: MovieImageURLBuilderStub(),
            searchDebounce: .zero
        )
        let sut = MoviesViewController(
            presenter: presenter,
            makeFilter: { _, _ in UIViewController() },
            makeDetails: destination
        )
        presenter.view = sut

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
