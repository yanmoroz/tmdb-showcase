import DomainKit
import UIKit

/// Where the scenes are assembled.
///
/// A named type rather than a method on the scene delegate, for the reason
/// MVC-App gives: it takes repositories rather than building them, so opening a
/// store stays the scene delegate's business and this can be exercised without
/// touching the disk.
///
/// A scene is a view, an interactor, a presenter and a router. The view gets its
/// interactor and router, the interactor its presenter and the router its data
/// store through `init`. What cannot go through `init` — `presenter.viewController`
/// and `router.viewController` — is `weak`, assigned afterwards, and fails
/// silently if forgotten: the screen builds and launches, then never draws, or
/// never leads anywhere.
enum CompositionRoot {
    static func makeMovies(
        movies: any MoviesRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> UINavigationController {
        let presenter = MoviesPresenter(imageURLBuilder: imageURLBuilder)
        let interactor = MoviesInteractor(
            presenter: presenter,
            fetchMovies: FetchMovies(repository: movies),
            fetchWatchlistIDs: FetchWatchlistIDs(repository: watchlist),
            addToWatchlist: AddToWatchlist(repository: watchlist),
            removeFromWatchlist: RemoveFromWatchlist(repository: watchlist)
        )
        let router = MoviesRouter(dataStore: interactor)
        let view = MoviesViewController(interactor: interactor, router: router)

        presenter.viewController = view
        router.viewController = view

        return UINavigationController(rootViewController: view)
    }
}
