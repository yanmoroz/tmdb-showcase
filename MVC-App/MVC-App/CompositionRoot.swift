import UIKit
import DomainKit
import DataKit

/// Where the screens are assembled.
///
/// A named type rather than a method on the scene delegate: two tabs now want the
/// same repositories, the same image builder and the same watchlist use cases,
/// and both push the same details screen. It takes repositories rather than
/// building them so that opening a store stays the scene delegate's business —
/// and so this can be exercised without touching the disk.
enum CompositionRoot {
    static func makeTabBar(
        movies: any MoviesRepository,
        genres: any GenresRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UITabBarController {
        let tabBar = UITabBarController()
        tabBar.viewControllers = [
            makeMoviesTab(movies: movies, genres: genres, watchlist: watchlist, imageURLBuilder: imageURLBuilder),
            makeWatchlistTab(movies: movies, watchlist: watchlist, imageURLBuilder: imageURLBuilder),
        ]
        return tabBar
    }

    /// Each tab owns its navigation controller: `showDetails(for:)` guards on
    /// being the top view controller, which only holds per stack.
    private static func makeMoviesTab(
        movies: any MoviesRepository,
        genres: any GenresRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UINavigationController {
        let root = MoviesViewController(
            fetchMovies: FetchMovies(repository: movies),
            fetchGenres: FetchGenres(repository: genres),
            fetchMovieDetails: FetchMovieDetails(repository: movies),
            fetchWatchlistIDs: FetchWatchlistIDs(repository: watchlist),
            addToWatchlist: AddToWatchlist(repository: watchlist),
            removeFromWatchlist: RemoveFromWatchlist(repository: watchlist),
            imageURLBuilder: imageURLBuilder
        )
        root.tabBarItem = UITabBarItem(title: "Movies", image: UIImage(systemName: "film"), tag: 0)
        return UINavigationController(rootViewController: root)
    }

    private static func makeWatchlistTab(
        movies: any MoviesRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UINavigationController {
        let root = WatchlistViewController(
            fetchWatchlist: FetchWatchlist(repository: watchlist),
            fetchMovieDetails: FetchMovieDetails(repository: movies),
            fetchWatchlistIDs: FetchWatchlistIDs(repository: watchlist),
            addToWatchlist: AddToWatchlist(repository: watchlist),
            removeFromWatchlist: RemoveFromWatchlist(repository: watchlist),
            imageURLBuilder: imageURLBuilder
        )
        root.tabBarItem = UITabBarItem(title: "Watchlist", image: UIImage(systemName: "bookmark"), tag: 1)
        return UINavigationController(rootViewController: root)
    }
}
