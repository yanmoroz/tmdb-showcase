import DomainKit
import UIKit

/// Where the root module is assembled; each router builds the modules it leads to.
///
/// A named type rather than a method on the scene delegate, for the reason
/// MVC-App gives: it takes repositories rather than building them, so opening a
/// store stays the scene delegate's business and this can be exercised without
/// touching the disk.
///
/// A module is a view, a presenter, an interactor and a router, held together by
/// three `weak` back-references — `presenter.view`, `interactor.output` and
/// `router.viewController`. Each fails silently if forgotten: the screen builds
/// and launches, then never draws, never hears back, or never leads anywhere.
enum CompositionRoot {
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
        let router = MoviesRouter(genres: genres)
        let presenter = MoviesPresenter(
            interactor: interactor,
            router: router,
            imageURLBuilder: imageURLBuilder
        )
        let view = MoviesViewController(presenter: presenter)

        presenter.view = view
        interactor.output = presenter
        router.viewController = view

        return UINavigationController(rootViewController: view)
    }
}
