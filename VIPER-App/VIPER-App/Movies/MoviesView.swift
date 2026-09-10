import PresentationKit

/// What the presenter may ask of the movies screen.
///
/// Commands, with one exception: `lastVisibleItem()` is a question, and it is
/// the seam where a passive view leaks. After a page lands the presenter has to
/// know whether the reader is already at the bottom — `willDisplay` fired for
/// those cells while the request was in flight and found a load in progress, so
/// without asking, the list stalls with no cell left to trigger the next page.
@MainActor
protocol MoviesView: AnyObject {
    func show(_ movies: [MovieCell.Model])
    func updateItem(at index: Int, with model: MovieCell.Model)
    func lastVisibleItem() -> Int?

    func showLoading()
    func showEmpty(isSearch: Bool)
    func showFailure(_ message: String, retry: Bool)
    func hideOverlay()

    func showToast(_ message: String)
    func endRefreshing()
    func scrollToTop()
    func setInputsEnabled(source: Bool, filter: Bool)
}

/// What the movies screen reports.
@MainActor
protocol MoviesViewOutput {
    func viewDidLoad()
    func viewWillAppear()

    func searchTextChanged(_ text: String)
    func didChangeSource(_ source: MoviesFilter.Source)
    func didTapFilter()
    func didPullToRefresh()
    func didTapRetry()

    func willDisplayItem(at index: Int)
    func didSelectItem(at index: Int)
    func didToggleWatchlist(at index: Int)
}
