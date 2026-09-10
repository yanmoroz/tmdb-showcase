import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import DataKit
@testable import VIPER_App

/// Assembly only — no store is opened, because `CompositionRoot` takes
/// repositories rather than building them.
@MainActor
@Suite("CompositionRoot")
struct CompositionRootTests {
    /// Each of these is `weak` and assigned once every object exists, so each is
    /// one forgotten line away from a module that builds and silently does nothing.
    @Test("The movies module is wired every way")
    func moviesIsWiredEveryWay() throws {
        let navigation = makeMovies()
        let view = try #require(navigation.viewControllers.first as? MoviesViewController)
        let presenter = try #require(view.presenter as? MoviesPresenter)
        let interactor = try #require(presenter.interactor as? MoviesInteractor)
        let router = try #require(presenter.router as? MoviesRouter)

        #expect(presenter.view === view)
        #expect(interactor.output === presenter)
        #expect(router.viewController === view)
    }

    @Test("The movies screen gets a navigation stack")
    func moviesGetsANavigationStack() {
        let navigation = makeMovies()

        #expect(navigation.viewControllers.count == 1)
        #expect(navigation.viewControllers.first is MoviesViewController)
    }

    /// The only test where the real interactor answers the real presenter: the
    /// loading flag set on the way out has to clear on the way back.
    @Test("A page travels the whole module to the screen")
    func pageTravelsTheWholeModule() async throws {
        let navigation = makeMovies(page: .fixture(items: Movie.fixtures(count: 3)))
        let view = try #require(navigation.viewControllers.first as? MoviesViewController)

        view.loadViewIfNeeded()

        try await waitUntil { view.testItemCount == 3 && !view.testShowsOverlay }
    }

    // MARK: - Helpers

    private func makeMovies(page: Page<Movie> = .empty()) -> UINavigationController {
        CompositionRoot.makeMovies(
            movies: MoviesRepositoryStub(moviesResult: .success(page)),
            genres: GenresRepositoryStub(),
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
