import DataKit
import DomainKit
import PresentationKit
import UIKit

/// Where the screens are assembled.
///
/// A named type rather than a method on the scene delegate, for the reason
/// MVC-App gives: it takes repositories rather than building them, so opening a
/// store stays the scene delegate's business and this can be exercised without
/// touching the disk.
///
/// Every screen here is three steps — presenter, view, and the back-reference
/// between them. That last one fails silently if forgotten: `view` is weak, so a
/// missed assignment leaves it nil and the screen simply never renders.
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

    /// Each tab owns its navigation controller: `showDetails(for:)` guards on
    /// being the top view controller, which only holds per stack.
    static func makeMovies(
        movies: any MoviesRepository,
        genres: any GenresRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UINavigationController {
        let presenter = MoviesPresenter(
            fetchMovies: FetchMovies(repository: movies),
            fetchWatchlistIDs: FetchWatchlistIDs(repository: watchlist),
            addToWatchlist: AddToWatchlist(repository: watchlist),
            removeFromWatchlist: RemoveFromWatchlist(repository: watchlist),
            imageURLBuilder: imageURLBuilder
        )
        let view = MoviesViewController(
            presenter: presenter,
            makeFilter: { selection, onApply in
                makeMoviesFilter(
                    fetchGenres: FetchGenres(repository: genres),
                    selection: selection,
                    onApply: onApply
                )
            },
            makeDetails: { movie in
                makeMovieDetails(
                    movie: movie,
                    movies: movies,
                    watchlist: watchlist,
                    imageURLBuilder: imageURLBuilder
                )
            }
        )
        presenter.view = view
        view.tabBarItem = UITabBarItem(title: "Movies", image: UIImage(systemName: "film"), tag: 0)

        return UINavigationController(rootViewController: view)
    }

    static func makeWatchlist(
        movies: any MoviesRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UINavigationController {
        let presenter = WatchlistPresenter(
            fetchWatchlist: FetchWatchlist(repository: watchlist),
            addToWatchlist: AddToWatchlist(repository: watchlist),
            removeFromWatchlist: RemoveFromWatchlist(repository: watchlist),
            imageURLBuilder: imageURLBuilder
        )
        let view = WatchlistViewController(
            presenter: presenter,
            makeDetails: { movie in
                makeMovieDetails(
                    movie: movie,
                    movies: movies,
                    watchlist: watchlist,
                    imageURLBuilder: imageURLBuilder
                )
            }
        )
        presenter.view = view
        view.tabBarItem = UITabBarItem(title: "Watchlist", image: UIImage(systemName: "bookmark"), tag: 1)

        return UINavigationController(rootViewController: view)
    }

    static func makeMoviesFilter(
        fetchGenres: any FetchGenresUseCase,
        selection: MoviesFilter,
        onApply: @escaping (MoviesFilter) -> Void
    ) -> UIViewController {
        let presenter = MoviesFilterPresenter(
            fetchGenres: fetchGenres,
            selection: selection,
            onApply: onApply
        )
        let view = MoviesFilterViewController(presenter: presenter)
        presenter.view = view
        return view
    }

    static func makeMovieDetails(
        movie: Movie,
        movies: any MoviesRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UIViewController {
        let presenter = MovieDetailsPresenter(
            movie: movie,
            fetchDetails: FetchMovieDetails(repository: movies),
            fetchWatchlistIDs: FetchWatchlistIDs(repository: watchlist),
            addToWatchlist: AddToWatchlist(repository: watchlist),
            removeFromWatchlist: RemoveFromWatchlist(repository: watchlist),
            imageURLBuilder: imageURLBuilder
        )
        let view = MovieDetailsViewController(presenter: presenter)
        presenter.view = view
        return view
    }
}
