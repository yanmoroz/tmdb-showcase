import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
@testable import MVC_App
import PresentationKit

@MainActor
@Suite("MovieDetailsViewController")
final class MovieDetailsViewControllerTests {
    nonisolated(unsafe) private weak var trackedSUT: MovieDetailsViewController?
    private var trackedLocation: SourceLocation?

    private let watchlistIDs = FetchWatchlistIDsStub()
    private let addToWatchlist = AddToWatchlistStub()
    private let removeFromWatchlist = RemoveFromWatchlistStub()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The details controller outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    @Test("Details are requested for the seeded movie")
    func requestsDetailsOnLoad() async throws {
        let (sut, fetchDetails) = makeSUT(movie: .fixture(id: 42))

        sut.loadViewIfNeeded()
        try await waitUntil { await fetchDetails.calls.map(\.id) == [42] }
    }

    /// The fattest mutant this screen can hide: a perfect projection that never
    /// reaches a label. Also pins that the seed draws before the request lands.
    @Test("The seeded title draws first, then the loaded one replaces it")
    func appliesTheModelToTheLabels() async throws {
        let (sut, _) = makeSUT(
            movie: .fixture(title: "Seeded Title"),
            details: .success(.fixture(title: "Loaded Title"))
        )

        sut.loadViewIfNeeded()
        #expect(sut.text(for: MovieDetailsViewController.Identifier.title) == "Seeded Title")

        try await waitUntil {
            sut.text(for: MovieDetailsViewController.Identifier.title) == "Loaded Title"
        }
    }

    @Test("A failure offers Retry, and retrying refetches")
    func retriesAfterFailure() async throws {
        let (sut, fetchDetails) = makeSUT(details: .failure(.network(.offline)))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.visibleStatus?.button.title == "Retry" }

        sut.reload()
        try await waitUntil { await fetchDetails.calls.count == 2 }
    }

    /// The regression guard for the mistake already made once on the filter
    /// screen: a screen-wide overlay would cover the seeded title and artwork,
    /// which did not fail and are the whole reason the screen is seeded.
    @Test("Nothing ever covers the seeded content", arguments: [
        Result<MovieDetails, AppError>.success(.fixture()),
        .failure(.network(.offline)),
        .failure(.regionRestricted),
    ])
    func neverUsesAScreenWideOverlay(details: Result<MovieDetails, AppError>) async throws {
        let (sut, fetchDetails) = makeSUT(details: details)

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchDetails.calls.isEmpty }
        await drainPendingWork()

        #expect(sut.currentUnavailableConfiguration == nil)
    }

    // MARK: - Watchlist

    @Test("The bookmark shows what the store already holds")
    func reflectsSavedState() async throws {
        await watchlistIDs.setResult(.success([42]))
        let (sut, _) = makeSUT(movie: .fixture(id: 42))

        sut.loadViewIfNeeded()

        try await waitUntil {
            sut.navigationItem.rightBarButtonItem?.accessibilityLabel == "Remove from watchlist"
        }
    }

    @Test("The bookmark saves the seeded movie")
    func savesTheSeededMovie() async throws {
        let (sut, _) = makeSUT(movie: .fixture(id: 42))

        sut.loadViewIfNeeded()
        try await waitUntil { await self.watchlistIDs.callCount >= 1 }

        sut.simulateBookmarkTap()

        try await waitUntil { await self.addToWatchlist.calls.map(\.id) == [42] }
        await drainPendingWork()
    }

    @Test("A failed save puts the bookmark back")
    func revertsAFailedSave() async throws {
        await addToWatchlist.setResult(.failure(.storage))
        let (sut, _) = makeSUT(movie: .fixture(id: 42))

        sut.loadViewIfNeeded()
        try await waitUntil { await self.watchlistIDs.callCount >= 1 }

        sut.simulateBookmarkTap()

        try await waitUntil {
            sut.navigationItem.rightBarButtonItem?.accessibilityLabel == "Add to watchlist"
        }
        #expect(sut.view.firstSubview(of: ToastView.self) != nil)
        await drainPendingWork()
    }

    // MARK: - Factory

    private func makeSUT(
        movie: Movie = .fixture(),
        details: Result<MovieDetails, AppError> = .success(.fixture()),
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (sut: MovieDetailsViewController, fetchDetails: FetchMovieDetailsStub) {
        let fetchDetails = FetchMovieDetailsStub(result: details)
        let sut = MovieDetailsViewController(
            movie: movie,
            fetchDetails: fetchDetails,
            fetchWatchlistIDs: watchlistIDs,
            addToWatchlist: addToWatchlist,
            removeFromWatchlist: removeFromWatchlist,
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchDetails)
    }
}

@MainActor
private extension MovieDetailsViewController {
    /// The inline status view, or nil when it is hidden — the screen's own
    /// loading and failure surface, as opposed to a screen-wide one.
    var visibleStatus: UIContentUnavailableConfiguration? {
        autoreleasepool {
            guard
                let status = view.firstSubview(of: UIContentUnavailableView.self),
                !status.isHidden
            else { return nil }
            return status.configuration as? UIContentUnavailableConfiguration
        }
    }

    func text(for identifier: String) -> String? {
        autoreleasepool {
            view.firstSubview(of: UILabel.self, identifier: identifier)?.text
        }
    }

    func simulateBookmarkTap() {
        autoreleasepool {
            navigationItem.rightBarButtonItem?.primaryAction?.performWithSender(nil, target: nil)
        }
    }

    var currentUnavailableConfiguration: UIContentUnavailableConfiguration? {
        autoreleasepool {
            setNeedsUpdateContentUnavailableConfiguration()
            view.layoutIfNeeded()
        }
        return contentUnavailableConfiguration as? UIContentUnavailableConfiguration
    }
}
