import Testing
import UIKit
import PresentationKit
@testable import VIPER_App

/// The grid's job is honouring ``WatchlistView`` and reporting what the reader
/// does. What to show is `WatchlistPresenterTests`.
@MainActor
@Suite("WatchlistViewController")
final class WatchlistViewControllerTests {
    nonisolated(unsafe) private weak var trackedSUT: WatchlistViewController?
    private var trackedLocation: SourceLocation?

    private let presenter = WatchlistViewOutputSpy()

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

            sut.show(models(count: 3))

            #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 3)
        }
    }

    @Test("An empty watchlist says how to fill it")
    func emptyStateIsDrawn() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showEmpty()

            #expect(sut.currentUnavailableConfiguration?.text == "Nothing saved yet")
        }
    }

    // MARK: - Reports

    @Test("Appearing is reported")
    func appearanceIsReported() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.beginAppearanceTransition(true, animated: false)
            sut.endAppearanceTransition()

            #expect(presenter.events == [.viewWillAppear])
        }
    }

    @Test("A retryable failure draws a button that reports its tap")
    func retryIsReported() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showFailure("Couldn't read the watchlist.", retry: true)
            let configuration = sut.currentUnavailableConfiguration
            configuration?.buttonProperties.primaryAction?.performWithSender(nil, target: nil)

            #expect(configuration?.button.title == "Retry")
            #expect(presenter.events.last == .didTapRetry)
        }
    }

    @Test("Selecting a film reports its position")
    func selectionIsReported() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.show(models(count: 3))

            sut.collectionView(sut.testCollectionView, didSelectItemAt: IndexPath(item: 2, section: 0))

            #expect(presenter.events.last == .didSelectItem(2))
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
                cellForItemAt: IndexPath(item: 1, section: 0)
            ) as? MovieCell
            cell?.onToggleWatchlist?()

            #expect(presenter.events.last == .didToggleWatchlist(1))
        }
    }

    // MARK: - Helpers

    private func makeSUT(sourceLocation: SourceLocation = #_sourceLocation) -> WatchlistViewController {
        let sut = WatchlistViewController(presenter: presenter)

        trackedSUT = sut
        trackedLocation = sourceLocation
        return sut
    }

    private func models(count: Int) -> [MovieCell.Model] {
        (0..<count).map {
            MovieCell.Model(posterURL: nil, title: "Fixture \($0)", year: "2024", rating: "★ 7.5", isSaved: true)
        }
    }
}

/// Records what the grid reported.
@MainActor
final class WatchlistViewOutputSpy: WatchlistViewOutput {
    enum Event: Equatable {
        case viewWillAppear
        case didTapRetry
        case didSelectItem(Int)
        case didToggleWatchlist(Int)
    }

    private(set) var events: [Event] = []

    func viewWillAppear() { events.append(.viewWillAppear) }
    func didTapRetry() { events.append(.didTapRetry) }
    func didSelectItem(at index: Int) { events.append(.didSelectItem(index)) }
    func didToggleWatchlist(at index: Int) { events.append(.didToggleWatchlist(index)) }
}

// MARK: - Scaffolding the controller cannot be touched without

@MainActor
private extension WatchlistViewController {
    var testCollectionView: UICollectionView {
        guard let collectionView = view.firstSubview(of: UICollectionView.self) else {
            preconditionFailure("WatchlistViewController stopped containing a UICollectionView")
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
}
