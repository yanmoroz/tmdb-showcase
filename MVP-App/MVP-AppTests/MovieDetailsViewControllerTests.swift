import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import MVP_App

/// The card's job is turning one projection into labels. Which values it
/// contains is `MovieDetailsPresenterTests`.
@MainActor
@Suite("MovieDetailsViewController")
final class MovieDetailsViewControllerTests {
    private weak var trackedSUT: MovieDetailsViewController?
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

    @Test("The projection reaches the labels")
    func modelReachesTheLabels() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.show(model(title: "Dune", overview: "Sand."))

            #expect(sut.text(for: MovieDetailsViewController.Identifier.title) == "Dune")
            #expect(sut.text(for: MovieDetailsViewController.Identifier.overview) == "Sand.")
        }
    }

    @Test("An absent field hides its label rather than blanking it")
    func absentFieldHidesItsLabel() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.show(model(title: "Dune", overview: nil))

            #expect(sut.label(for: MovieDetailsViewController.Identifier.overview)?.isHidden == true)
        }
    }

    @Test("The bookmark reflects what the presenter says")
    func bookmarkReflectsSavedState() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.setSaved(true)
            #expect(sut.navigationItem.rightBarButtonItem?.accessibilityLabel == "Remove from watchlist")

            sut.setSaved(false)
            #expect(sut.navigationItem.rightBarButtonItem?.accessibilityLabel == "Add to watchlist")
        }
    }

    @Test("A failure appears beside the card, never over it")
    func failureIsAdditive() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.show(model(title: "Dune", overview: "Sand."))

            sut.showFailure("No internet connection.", retry: true)

            #expect(sut.text(for: MovieDetailsViewController.Identifier.title) == "Dune")
            #expect(sut.statusView?.isHidden == false)
            #expect(sut.contentUnavailableConfiguration == nil)
        }
    }

    @Test("A retryable failure draws a button")
    func failureOffersRetry() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showFailure("No internet connection.", retry: true)

            #expect(sut.statusConfiguration?.button.title == "Retry")
        }
    }

    @Test("An unfixable failure draws none")
    func failureWithoutRetry() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showFailure("TMDB is not available in your region.", retry: false)

            // `.empty()` always carries a button, so the title is what tells an
            // offered retry from an absent one.
            #expect(sut.statusConfiguration?.button.title == nil)
        }
    }

    @Test("Hiding the status leaves the card alone")
    func hideStatusKeepsTheCard() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.show(model(title: "Dune", overview: "Sand."))
            sut.showLoading()

            sut.hideStatus()

            #expect(sut.statusView?.isHidden == true)
            #expect(sut.text(for: MovieDetailsViewController.Identifier.title) == "Dune")
        }
    }

    @Test("A toast lands in the hierarchy")
    func toastIsShown() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showToast("Couldn't save to this device.")

            #expect(sut.view.firstSubview(of: ToastView.self) != nil)
        }
    }

    // MARK: - Helpers

    private func makeSUT(sourceLocation: SourceLocation = #_sourceLocation) -> MovieDetailsViewController {
        let presenter = MovieDetailsPresenter(
            movie: .fixture(id: 1),
            fetchDetails: FetchMovieDetailsStub(result: .failure(.cancelled)),
            fetchWatchlistIDs: FetchWatchlistIDsStub(),
            addToWatchlist: AddToWatchlistStub(),
            removeFromWatchlist: RemoveFromWatchlistStub(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        let sut = MovieDetailsViewController(presenter: presenter)
        presenter.view = sut

        trackedSUT = sut
        trackedLocation = sourceLocation
        return sut
    }

    private func model(title: String, overview: String?) -> MovieDetailsModel {
        MovieDetailsModel(
            title: title,
            posterURL: nil,
            backdropURL: nil,
            originalTitle: nil,
            tagline: nil,
            genres: nil,
            metadata: "2024 · ★ 7.5",
            overview: overview,
            trailerKey: nil
        )
    }
}

// MARK: - Scaffolding the controller cannot be touched without

@MainActor
private extension MovieDetailsViewController {
    func label(for identifier: String) -> UILabel? {
        autoreleasepool {
            view.firstSubview(of: UILabel.self, identifier: identifier)
        }
    }

    func text(for identifier: String) -> String? {
        label(for: identifier)?.text
    }

    var statusView: UIContentUnavailableView? {
        autoreleasepool {
            view.firstSubview(of: UIContentUnavailableView.self)
        }
    }

    var statusConfiguration: UIContentUnavailableConfiguration? {
        statusView?.configuration as? UIContentUnavailableConfiguration
    }
}
