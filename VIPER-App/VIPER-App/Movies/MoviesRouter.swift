import UIKit
import DomainKit
import PresentationKit

@MainActor
protocol MoviesRouterInput {
    func showFilter(_ selection: MoviesFilter, output: any MoviesFilterModuleOutput)
    func showDetails(for movie: Movie)
}

/// Builds the modules this screen leads to and presents them from
/// `viewController`, which is `weak`: the view owns the presenter that owns this.
@MainActor
final class MoviesRouter: MoviesRouterInput {
    weak var viewController: UIViewController?

    private let movies: any MoviesRepository
    private let genres: any GenresRepository
    private let watchlist: any WatchlistRepository
    private let imageURLBuilder: any MovieImageURLBuilder

    init(
        movies: any MoviesRepository,
        genres: any GenresRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) {
        self.movies = movies
        self.genres = genres
        self.watchlist = watchlist
        self.imageURLBuilder = imageURLBuilder
    }

    func showFilter(_ selection: MoviesFilter, output: any MoviesFilterModuleOutput) {
        guard let viewController, viewController.presentedViewController == nil else { return }

        let filter = MoviesFilterRouter.makeModule(genres: genres, selection: selection, output: output)
        viewController.present(UINavigationController(rootViewController: filter), animated: true)
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
