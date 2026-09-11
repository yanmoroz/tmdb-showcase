import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import DataKit
@testable import VIP_App

/// Assembly only — no store is opened, because `CompositionRoot` takes
/// repositories rather than building them.
@MainActor
@Suite("CompositionRoot")
struct CompositionRootTests {
    /// The two `viewController`s are `weak` and assigned once every object exists,
    /// so each is one forgotten line away from a scene that builds and silently
    /// does nothing. The rest go through `init`, which leaves only whether the
    /// right objects were handed over.
    @Test("The movies scene is wired every way")
    func moviesIsWiredEveryWay() throws {
        let navigation = makeMovies()
        let view = try #require(navigation.viewControllers.first as? MoviesViewController)
        let interactor = try #require(view.interactor as? MoviesInteractor)
        let presenter = try #require(interactor.presenter as? MoviesPresenter)
        let router = try #require(view.router as? MoviesRouter)

        #expect(presenter.viewController === view)
        #expect(router.viewController === view)
        #expect(router.dataStore === interactor)
    }

    @Test("The movies screen gets a navigation stack")
    func moviesGetsANavigationStack() {
        let navigation = makeMovies()

        #expect(navigation.viewControllers.count == 1)
        #expect(navigation.viewControllers.first is MoviesViewController)
    }

    /// Held strongly, either `viewController` closes a loop through the
    /// controller, and the scene outlives its stack.
    @Test("The movies scene goes away with its navigation stack")
    func moviesIsReleased() {
        weak var view: UIViewController?

        autoreleasepool {
            view = makeMovies().viewControllers.first
        }

        #expect(view == nil)
    }

    /// The only test where the real interactor answers through the real presenter
    /// to the real view.
    @Test("A page travels the whole scene to the screen")
    func pageTravelsTheWholeScene() async throws {
        let navigation = makeMovies(page: .fixture(items: Movie.fixtures(count: 3)))
        let view = try #require(navigation.viewControllers.first as? MoviesViewController)

        view.loadViewIfNeeded()

        try await waitUntil { view.testItemCount == 3 && !view.testShowsOverlay }
    }

    // MARK: - Helpers

    private func makeMovies(page: Page<Movie> = .empty()) -> UINavigationController {
        CompositionRoot.makeMovies(
            movies: MoviesRepositoryStub(moviesResult: .success(page)),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
    }
}

// MARK: - Scaffolding

@MainActor
private extension MoviesViewController {
    var testItemCount: Int {
        autoreleasepool {
            view.firstSubview(of: UICollectionView.self)?.numberOfItems(inSection: 0) ?? 0
        }
    }

    var testShowsOverlay: Bool {
        autoreleasepool {
            setNeedsUpdateContentUnavailableConfiguration()
            view.layoutIfNeeded()
            return contentUnavailableConfiguration != nil
        }
    }
}
