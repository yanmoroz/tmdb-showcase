import DomainKit

/// The details screen leads nowhere, so there is no router instance to hold and
/// no `viewController` to forget — only the assembly the routers that open it
/// call, and they decide how it appears.
@MainActor
enum MovieDetailsRouter {
    static func makeModule(
        movie: Movie,
        movies: any MoviesRepository,
        watchlist: any WatchlistRepository,
        imageURLBuilder: any MovieImageURLBuilder
    ) -> MovieDetailsViewController {
        let interactor = MovieDetailsInteractor(
            fetchDetails: FetchMovieDetails(repository: movies),
            fetchWatchlistIDs: FetchWatchlistIDs(repository: watchlist),
            addToWatchlist: AddToWatchlist(repository: watchlist),
            removeFromWatchlist: RemoveFromWatchlist(repository: watchlist)
        )
        let presenter = MovieDetailsPresenter(
            movie: movie,
            interactor: interactor,
            imageURLBuilder: imageURLBuilder
        )
        let view = MovieDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.output = presenter

        return view
    }
}
