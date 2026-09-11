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
    // MARK: - Tabs

    @Test("Both tabs get their own navigation stack")
    func tabsGetTheirOwnStacks() {
        let tabBar = makeTabBar()

        #expect(tabBar.viewControllers?.count == 2)
        #expect(tabBar.viewControllers?.allSatisfy { $0 is UINavigationController } == true)
    }

    @Test("The tabs are Movies and Watchlist, in that order")
    func tabsAreInOrder() {
        let tabBar = makeTabBar()
        let roots = tabBar.viewControllers?.compactMap { ($0 as? UINavigationController)?.viewControllers.first }

        #expect(roots?.first is MoviesViewController)
        #expect(roots?.last is WatchlistViewController)
        #expect(tabBar.viewControllers?.map(\.tabBarItem.title) == ["Movies", "Watchlist"])
    }

    // MARK: - Movies

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

    /// The real interactor answering the real presenter: the loading flag set on
    /// the way out has to clear on the way back.
    @Test("A page travels the whole module to the screen")
    func pageTravelsTheWholeModule() async throws {
        let navigation = makeMovies(page: .fixture(items: Movie.fixtures(count: 3)))
        let view = try #require(navigation.viewControllers.first as? MoviesViewController)

        view.loadViewIfNeeded()

        try await waitUntil { view.testItemCount == 3 && !view.testShowsOverlay }
    }

    /// The router's `viewController` is otherwise only checked for identity; this
    /// walks the whole path from a tap to a pushed screen.
    @Test("Selecting a loaded film pushes its details onto the movies stack")
    func selectionPushesDetails() async throws {
        let navigation = makeMovies(page: .fixture(items: Movie.fixtures(count: 3)))
        let view = try #require(navigation.viewControllers.first as? MoviesViewController)

        view.loadViewIfNeeded()
        try await waitUntil { view.testItemCount == 3 }
        view.presenter.didSelectItem(at: 1)

        try await waitUntil { navigation.viewControllers.last is MovieDetailsViewController }
    }

    // MARK: - Watchlist

    @Test("The watchlist module is wired every way")
    func watchlistIsWiredEveryWay() throws {
        let navigation = makeWatchlist()
        let view = try #require(navigation.viewControllers.first as? WatchlistViewController)
        let presenter = try #require(view.presenter as? WatchlistPresenter)
        let interactor = try #require(presenter.interactor as? WatchlistInteractor)
        let router = try #require(presenter.router as? WatchlistRouter)

        #expect(presenter.view === view)
        #expect(interactor.output === presenter)
        #expect(router.viewController === view)
    }

    @Test("Saved films travel the whole module to the screen")
    func savedFilmsTravelTheWholeModule() async throws {
        let navigation = makeWatchlist(saved: Movie.fixtures(count: 2))
        let view = try #require(navigation.viewControllers.first as? WatchlistViewController)

        view.loadViewIfNeeded()
        view.beginAppearanceTransition(true, animated: false)
        view.endAppearanceTransition()

        try await waitUntil { view.testItemCount == 2 && !view.testShowsOverlay }
    }

    // MARK: - Helpers

    private func makeTabBar() -> UITabBarController {
        CompositionRoot.makeTabBar(
            movies: MoviesRepositoryStub(),
            genres: GenresRepositoryStub(),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
    }

    private func makeMovies(page: Page<Movie> = .empty()) -> UINavigationController {
        CompositionRoot.makeMovies(
            movies: MoviesRepositoryStub(moviesResult: .success(page)),
            genres: GenresRepositoryStub(),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
    }

    private func makeWatchlist(saved: [Movie] = []) -> UINavigationController {
        CompositionRoot.makeWatchlist(
            movies: MoviesRepositoryStub(),
            watchlist: WatchlistRepositoryStub(savedMoviesResult: .success(saved)),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
    }
}

// MARK: - Scaffolding

@MainActor
private extension UIViewController {
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
