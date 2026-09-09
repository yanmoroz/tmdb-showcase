import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import DataKit
import PresentationKit
@testable import MVP_App

/// Assembly only — no store is opened, because `CompositionRoot` takes
/// repositories rather than building them.
///
/// The back-reference from presenter to view is what these mostly guard: it is
/// `weak`, so forgetting it leaves a screen that builds, launches and never
/// draws anything.
@MainActor
@Suite("CompositionRoot")
struct CompositionRootTests {
    @Test("The movies screen is wired both ways")
    func moviesIsWiredBothWays() throws {
        let navigation = makeMovies()
        let view = try #require(navigation.viewControllers.first as? MoviesViewController)

        // A presenter that draws proves it found its view.
        view.loadViewIfNeeded()
        #expect(view.testHasRendered)
    }

    @Test("The movies screen gets a navigation stack")
    func moviesGetsANavigationStack() {
        let navigation = makeMovies()

        #expect(navigation.viewControllers.count == 1)
        #expect(navigation.viewControllers.first is MoviesViewController)
    }

    @Test("The filter sheet is wired both ways")
    func filterIsWiredBothWays() {
        let sheet = CompositionRoot.makeMoviesFilter(
            fetchGenres: FetchGenresStub(result: .success(Genre.fixtures)),
            selection: MoviesFilter(),
            onApply: { _ in }
        )
        let filter = sheet as? MoviesFilterViewController

        filter?.loadViewIfNeeded()
        // Sort options are drawn synchronously in viewDidLoad, so a populated
        // second section means the presenter reached its view.
        #expect(filter?.testTableView?.numberOfRows(inSection: 1) == MovieSortOption.allCases.count)
    }

    @Test("The details screen is wired both ways")
    func detailsIsWiredBothWays() {
        let screen = CompositionRoot.makeMovieDetails(
            movie: .fixture(id: 1, title: "Dune"),
            movies: MoviesRepositoryStub(),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        let details = screen as? MovieDetailsViewController

        details?.loadViewIfNeeded()
        #expect(details?.testTitleText == "Dune")
    }

    @Test("The watchlist screen is wired both ways")
    func watchlistIsWiredBothWays() throws {
        let navigation = CompositionRoot.makeWatchlist(
            movies: MoviesRepositoryStub(),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        let view = try #require(navigation.viewControllers.first as? WatchlistViewController)

        view.loadViewIfNeeded()
        view.beginAppearanceTransition(true, animated: false)
        #expect(view.testHasRendered)
    }

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

    @Test("An unavailable watchlist still builds the app")
    func buildsWithoutAWatchlist() {
        let navigation = CompositionRoot.makeMovies(
            movies: MoviesRepositoryStub(),
            genres: GenresRepositoryStub(),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )

        #expect(navigation.viewControllers.first is MoviesViewController)
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

    private func makeMovies() -> UINavigationController {
        CompositionRoot.makeMovies(
            movies: MoviesRepositoryStub(),
            genres: GenresRepositoryStub(),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
    }
}

// MARK: - Scaffolding

@MainActor
private extension MoviesViewController {
    /// The presenter renders on `viewDidLoad`; an empty grid with no overlay
    /// would mean it never got the chance.
    var testHasRendered: Bool {
        autoreleasepool {
            view.layoutIfNeeded()
            return contentUnavailableConfiguration != nil
        }
    }
}

@MainActor
private extension WatchlistViewController {
    /// The presenter renders on `viewWillAppear`; an empty grid with no overlay
    /// would mean it never got the chance.
    var testHasRendered: Bool {
        autoreleasepool {
            view.layoutIfNeeded()
            return contentUnavailableConfiguration != nil
        }
    }
}

@MainActor
private extension MoviesFilterViewController {
    var testTableView: UITableView? {
        autoreleasepool { view.firstSubview(of: UITableView.self) }
    }
}

@MainActor
private extension MovieDetailsViewController {
    var testTitleText: String? {
        autoreleasepool {
            view.firstSubview(of: UILabel.self, identifier: Identifier.title)?.text
        }
    }
}
