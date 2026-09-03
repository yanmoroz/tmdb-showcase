import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
@testable import MVC_App

@MainActor
@Suite("WatchlistViewController")
final class WatchlistViewControllerTests {
    private weak var trackedSUT: WatchlistViewController?
    private var trackedLocation: SourceLocation?

    private let removeFromWatchlist = RemoveFromWatchlistStub()
    private let addToWatchlist = AddToWatchlistStub()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The watchlist controller outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    @Test("Saved films appear in the grid")
    func showsSavedFilms() async throws {
        let (sut, _) = makeSUT(saved: .success(Movie.fixtures(count: 3)))

        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)

        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 3 }
    }

    @Test("An empty watchlist explains itself")
    func showsEmptyState() async throws {
        let (sut, fetchWatchlist) = makeSUT(saved: .success([]))

        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        try await waitUntil { await fetchWatchlist.callCount == 1 }
        await drainPendingWork()

        #expect(sut.currentUnavailableConfiguration?.text == "Nothing saved yet")
    }

    @Test("A failure offers Retry, and retrying re-reads")
    func retriesAfterFailure() async throws {
        let (sut, fetchWatchlist) = makeSUT(saved: .failure(.network(.offline)))

        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        try await waitUntil { sut.currentUnavailableConfiguration?.button.title == "Retry" }

        sut.load()
        try await waitUntil { await fetchWatchlist.callCount == 2 }
    }

    /// The list is re-read on every appearance because saving happens on the
    /// other tab and on the details screen, with no channel back.
    @Test("Returning to the tab re-reads the list")
    func reloadsOnEveryAppearance() async throws {
        let (sut, fetchWatchlist) = makeSUT(saved: .success(Movie.fixtures(count: 1)))

        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        try await waitUntil { await fetchWatchlist.callCount == 1 }

        sut.viewWillAppear(false)
        try await waitUntil { await fetchWatchlist.callCount == 2 }
    }

    /// Un-saving empties the mark but leaves the row, so a mis-tap is undone in
    /// place rather than chasing a film that vanished mid-scroll.
    @Test("Un-saving keeps the row until the next appearance")
    func keepsTheRowAfterUnsaving() async throws {
        let (sut, _) = makeSUT(saved: .success(Movie.fixtures(count: 2)))

        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 2 }

        sut.simulateWatchlistToggle(at: 0)
        try await waitUntil { await self.removeFromWatchlist.calls.count == 1 }

        #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 2)
        #expect(await removeFromWatchlist.calls == [1])
    }

    @Test("Toggling a removed film back saves it again")
    func reSavesAfterUnsaving() async throws {
        let (sut, _) = makeSUT(saved: .success(Movie.fixtures(count: 1)))

        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 1 }

        sut.simulateWatchlistToggle(at: 0)
        try await waitUntil { await self.removeFromWatchlist.calls.count == 1 }
        sut.simulateWatchlistToggle(at: 0)
        try await waitUntil { await self.addToWatchlist.calls.count == 1 }

        #expect(await addToWatchlist.calls.map(\.id) == [1])
    }

    // MARK: - Factory

    private func makeSUT(
        saved: Result<[Movie], AppError>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (sut: WatchlistViewController, fetchWatchlist: FetchWatchlistStub) {
        let fetchWatchlist = FetchWatchlistStub(result: saved)
        let sut = WatchlistViewController(
            fetchWatchlist: fetchWatchlist,
            fetchMovieDetails: FetchMovieDetailsStub(),
            fetchWatchlistIDs: FetchWatchlistIDsStub(),
            addToWatchlist: addToWatchlist,
            removeFromWatchlist: removeFromWatchlist,
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchWatchlist)
    }
}

@MainActor
private extension WatchlistViewController {
    var testCollectionView: UICollectionView {
        guard let collectionView = view.firstSubview(of: UICollectionView.self) else {
            preconditionFailure("WatchlistViewController stopped containing a UICollectionView")
        }
        return collectionView
    }

    var currentUnavailableConfiguration: UIContentUnavailableConfiguration? {
        autoreleasepool {
            setNeedsUpdateContentUnavailableConfiguration()
            view.layoutIfNeeded()
        }
        return contentUnavailableConfiguration as? UIContentUnavailableConfiguration
    }

    func simulateWatchlistToggle(at item: Int) {
        autoreleasepool {
            let cell = collectionView(
                testCollectionView,
                cellForItemAt: IndexPath(item: item, section: 0)
            ) as? MovieCell
            cell?.onToggleWatchlist?()
        }
    }
}
