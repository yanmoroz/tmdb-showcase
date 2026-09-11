import UIKit
import DomainKit

@MainActor
protocol WatchlistRouterInput {
    func showDetails(for movie: Movie)
}

/// Builds the details card and pushes it from `viewController`, which is `weak`:
/// the view owns the presenter that owns this.
@MainActor
final class WatchlistRouter: WatchlistRouterInput {
    weak var viewController: UIViewController?

    private let movies: any MoviesRepository
    private let watchlist: any WatchlistRepository
    private let imageURLBuilder: any MovieImageURLBuilder

    init(
        movies: any MoviesRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) {
        self.movies = movies
        self.watchlist = watchlist
        self.imageURLBuilder = imageURLBuilder
    }

    func showDetails(for movie: Movie) {
        guard
            let viewController,
            let navigation = viewController.navigationController,
            navigation.topViewController === viewController
        else { return }

        let details = MovieDetailsRouter.makeModule(
            movie: movie,
            movies: movies,
            watchlist: watchlist,
            imageURLBuilder: imageURLBuilder
        )
        navigation.pushViewController(details, animated: true)
    }
}
