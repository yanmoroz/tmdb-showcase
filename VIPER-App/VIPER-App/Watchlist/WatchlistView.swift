import PresentationKit

/// What the presenter may ask of the watchlist screen.
///
/// Deliberately the same vocabulary as ``MoviesView`` minus the inputs: it is the
/// same grid and the same cell, so a second set of names for the same commands
/// would be noise.
@MainActor
protocol WatchlistView: AnyObject {
    func show(_ movies: [MovieCell.Model])
    func updateItem(at index: Int, with model: MovieCell.Model)

    func showLoading()
    func showEmpty()
    func showFailure(_ message: String, retry: Bool)
    func hideOverlay()

    func showToast(_ message: String)
}

/// What the watchlist screen reports.
@MainActor
protocol WatchlistViewOutput {
    func viewWillAppear()
    func didTapRetry()

    func didSelectItem(at index: Int)
    func didToggleWatchlist(at index: Int)
}
