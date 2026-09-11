import DomainKit
import UIKit

/// Where the root modules and the tab bar are assembled; each router builds the
/// modules it leads to.
///
/// A named type rather than a method on the scene delegate, for the reason
/// MVC-App gives: it takes repositories rather than building them, so opening a
/// store stays the scene delegate's business and this can be exercised without
/// touching the disk.
///
/// A module is a view, a presenter, an interactor and — when it leads anywhere —
/// a router, held together by `weak` back-references: `presenter.view`,
/// `interactor.output` and `router.viewController`. Each fails silently if
/// forgotten: the screen builds and launches, then never draws, never hears
/// back, or never leads anywhere.
enum CompositionRoot {
    static func makeTabBar(
        movies: any MoviesRepository,
        genres: any GenresRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UITabBarController {
        let tabBar = UITabBarController()
        tabBar.viewControllers = [
            makeMovies(movies: movies, genres: genres, watchlist: watchlist, imageURLBuilder: imageURLBuilder),
            makeWatchlist(movies: movies, watchlist: watchlist, imageURLBuilder: imageURLBuilder),
        ]
        return tabBar
    }

    /// Each tab owns its navigation controller: a router pushes details only
    /// while its screen is the top of the stack, which only holds per stack.
    static func makeMovies(
        movies: any MoviesRepository,
        genres: any GenresRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UINavigationController {
        let interactor = MoviesInteractor(
            fetchMovies: FetchMovies(repository: movies),
            fetchWatchlistIDs: FetchWatchlistIDs(repository: watchlist),
            addToWatchlist: AddToWatchlist(repository: watchlist),
            removeFromWatchlist: RemoveFromWatchlist(repository: watchlist)
        )
        let router = MoviesRouter(
            movies: movies,
            genres: genres,
            watchlist: watchlist,
            imageURLBuilder: imageURLBuilder
        )
        let presenter = MoviesPresenter(
            interactor: interactor,
            router: router,
            imageURLBuilder: imageURLBuilder
        )
        let view = MoviesViewController(presenter: presenter)

        presenter.view = view
        interactor.output = presenter
        router.viewController = view
        view.tabBarItem = UITabBarItem(title: "Movies", image: UIImage(systemName: "film"), tag: 0)

        return UINavigationController(rootViewController: view)
    }

    static func makeWatchlist(
        movies: any MoviesRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UINavigationController {
        let interactor = WatchlistInteractor(
            fetchWatchlist: FetchWatchlist(repository: watchlist),
            addToWatchlist: AddToWatchlist(repository: watchlist),
            removeFromWatchlist: RemoveFromWatchlist(repository: watchlist)
        )
        let router = WatchlistRouter(
            movies: movies,
            watchlist: watchlist,
            imageURLBuilder: imageURLBuilder
        )
        let presenter = WatchlistPresenter(
            interactor: interactor,
            router: router,
            imageURLBuilder: imageURLBuilder
        )
        let view = WatchlistViewController(presenter: presenter)

        presenter.view = view
        interactor.output = presenter
        router.viewController = view
        view.tabBarItem = UITabBarItem(title: "Watchlist", image: UIImage(systemName: "bookmark"), tag: 1)

        return UINavigationController(rootViewController: view)
    }
}
