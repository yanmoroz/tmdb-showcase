import Foundation
import DomainKit
import PresentationKit

/// Everything the movies screen knows, and nothing it draws.
///
/// The view is `weak`: the controller owns this, and holding it back would keep
/// the pair alive forever.
@MainActor
final class MoviesPresenter {
    weak var view: (any MoviesView)?

    private let fetchMovies: any FetchMoviesUseCase
    private let fetchWatchlistIDs: any FetchWatchlistIDsUseCase
    private let addToWatchlist: any AddToWatchlistUseCase
    private let removeFromWatchlist: any RemoveFromWatchlistUseCase
    private let imageURLBuilder: any MovieImageURLBuilder

    /// What we are doing.
    ///
    /// The task lives inside the case on purpose: "loading with nothing in
    /// flight" and "a request nobody is waiting on" both become unrepresentable.
    private enum Activity {
        case idle
        case loading(Task<Void, Never>)
        case failed(AppError)
    }

    /// Two rows short of the end.
    private static let loadAheadItems = 6

    private var feed = Feed(query: .popular)
    private var activity: Activity = .idle

    /// The two independent inputs. `didSet` is what holds the invariant: an input
    /// cannot change without the query being recomputed from both.
    private var searchText: SearchText? { didSet { applyInputs() } }
    private var filter = MoviesFilter() { didSet { applyInputs() } }

    /// The raw field contents, which the debounce leaves `searchText` a beat
    /// behind. Availability is read from here so the controls are never live over
    /// a search that is about to start.
    private var typedSearch = ""

    /// Overlaid onto whatever the feed returned — the flag is deliberately not
    /// a field on `Movie`.
    private var savedIDs: Set<Movie.ID> = []

    private let searchDebouncer: Debouncer

    private var currentQuery: MoviesQuery {
        if let searchText { .search(searchText) } else { filter.query }
    }

    init(
        fetchMovies: any FetchMoviesUseCase,
        fetchWatchlistIDs: any FetchWatchlistIDsUseCase,
        addToWatchlist: any AddToWatchlistUseCase,
        removeFromWatchlist: any RemoveFromWatchlistUseCase,
        imageURLBuilder: any MovieImageURLBuilder,
        searchDebounce: Duration = .milliseconds(300)
    ) {
        self.fetchMovies = fetchMovies
        self.fetchWatchlistIDs = fetchWatchlistIDs
        self.addToWatchlist = addToWatchlist
        self.removeFromWatchlist = removeFromWatchlist
        self.imageURLBuilder = imageURLBuilder
        self.searchDebouncer = Debouncer(interval: searchDebounce)
    }

    deinit {
        if case .loading(let task) = activity {
            task.cancel()
        }
    }

    // MARK: - Lifecycle

    func viewDidLoad() {
        updateInputAvailability()
        reload()
    }

    func viewWillAppear() {
        // The details screen this list pushed can change what is saved, and
        // there is no channel back — so the list re-reads on the way in.
        reloadWatchlist()
    }

    // MARK: - Input

    func searchTextChanged(_ input: String) {
        typedSearch = input
        updateInputAvailability()

        searchDebouncer.schedule { [weak self] in
            // The failable init of SearchText *is* the "blank input is no reason
            // to hit the network" rule: nil means fall back to the filter.
            self?.searchText = SearchText(input)
        }
    }

    func didChangeSource(_ source: MoviesFilter.Source) {
        filter.source = source
    }

    func didTapFilter() {
        view?.showFilter(filter)
    }

    func didApplyFilter(_ filter: MoviesFilter) {
        self.filter = filter
    }

    func didPullToRefresh() {
        reload()
    }

    func didTapRetry() {
        reload()
    }

    func willDisplayItem(at index: Int) {
        loadNextPageIfNearEnd(index)
    }

    func didSelectItem(at index: Int) {
        guard feed.movies.indices.contains(index) else { return }
        view?.showDetails(for: feed[index])
    }

    // MARK: - Watchlist

    func didToggleWatchlist(at index: Int) {
        guard feed.movies.indices.contains(index) else { return }
        let movie = feed[index]
        let wasSaved = savedIDs.contains(movie.id)
        setSaved(!wasSaved, for: movie.id)

        Task { [weak self] in
            guard let self else { return }

            do {
                if wasSaved {
                    try await removeFromWatchlist(id: movie.id)
                } else {
                    try await addToWatchlist(movie)
                }
            } catch let error as AppError {
                setSaved(wasSaved, for: movie.id)
                view?.showToast(error.message)
            } catch {
                setSaved(wasSaved, for: movie.id)
                view?.showToast(AppError.unknown.message)
            }
        }
    }

    private func reloadWatchlist() {
        Task { [weak self] in
            guard let self, let saved = try? await fetchWatchlistIDs(), saved != savedIDs else { return }

            // A read that failed leaves the previous marks alone: showing every
            // film as unsaved would be a worse answer than a slightly old one.
            savedIDs = saved
            showFeed()
        }
    }

    private func setSaved(_ isSaved: Bool, for id: Movie.ID) {
        if isSaved {
            savedIDs.insert(id)
        } else {
            savedIDs.remove(id)
        }

        guard let item = feed.index(of: id) else { return }
        view?.updateItem(at: item, with: model(for: feed[item]))
    }

    // MARK: - Loading

    /// Reloading and changing the question are the same operation with a
    /// different argument — a direct consequence of `query` living inside `Feed`.
    private func setQuery(_ query: MoviesQuery) {
        if case .loading(let task) = activity {
            task.cancel()
        }
        activity = .idle
        feed = Feed(query: query)
        showFeed()
        view?.scrollToTop()

        loadNextPage()
    }

    private func reload() {
        setQuery(feed.query)
    }

    private func loadNextPage() {
        if case .loading = activity { return }
        guard let page = feed.nextPage else { return }

        activity = .loading(
            Task { [weak self] in
                guard let self else { return }

                let outcome: Result<Page<Movie>, AppError>
                do {
                    outcome = .success(try await fetchMovies(query: feed.query, page: page))
                } catch let error as AppError {
                    outcome = .failure(error)
                } catch {
                    outcome = .failure(.unknown)
                }

                // Cancelled while the request flew: another load owns the state
                // now, and the cancellation flag outlives the suspension.
                guard !Task.isCancelled else { return }

                switch outcome {
                case .success(let result): append(result)
                case .failure(let error): handle(error)
                }
            }
        )
        updateOverlay()
    }

    private func append(_ page: Page<Movie>) {
        view?.endRefreshing()
        feed.append(page)
        activity = .idle
        showFeed()

        // While the page was loading, willDisplay already fired for every cell
        // near the end and found a load in progress. Without this recheck the
        // list stalls at the bottom: no new cells appear, so nothing is left to
        // ask for the next page.
        // Nothing on screen means no reader to run out of items, so a page that
        // came back empty must not pull the next one on its own.
        if let lastVisibleItem = view?.lastVisibleItem() {
            loadNextPageIfNearEnd(lastVisibleItem)
        }
    }

    private func loadNextPageIfNearEnd(_ item: Int) {
        guard item >= feed.count - Self.loadAheadItems else { return }
        loadNextPage()
    }

    private func handle(_ error: AppError) {
        view?.endRefreshing()

        if feed.isEmpty {
            // Cancellation lands here too: a cancellation that is not followed by
            // a new load — a system one from URLSession, for instance — would
            // otherwise leave the screen with nothing to show and no way out.
            activity = .failed(error)
            updateOverlay()
        } else {
            activity = .idle
            updateOverlay()
            // The list already has content: a page error must not replace it,
            // and a cancellation is not worth reporting at all.
            if error != .cancelled {
                view?.showToast(error.message)
            }
        }
    }

    // MARK: - Rendering

    private func showFeed() {
        view?.show(feed.movies.map(model(for:)))
        updateOverlay()
    }

    /// Derived from the two axes rather than assigned by hand: an overlay cannot
    /// cover a non-empty list, because every branch that produces one requires an
    /// empty feed.
    private func updateOverlay() {
        switch activity {
        case .loading where feed.isEmpty:
            view?.showLoading()
        case .failed(let error):
            // Cancellation is not transient, so isRetryable leaves it out.
            // Retrying is still the only useful action left: nothing was loaded.
            view?.showFailure(error.message, retry: error.isRetryable || error == .cancelled)
        case .idle where feed.isEmpty:
            view?.showEmpty(isSearch: isSearching)
        default:
            view?.hideOverlay()
        }
    }

    private var isSearching: Bool {
        if case .search = feed.query { true } else { false }
    }

    /// A search overrides both, and `/trending` accepts neither genre nor sort,
    /// so under either the controls would be there to do nothing.
    private func updateInputAvailability() {
        let hasSearchText = SearchText(typedSearch) != nil

        view?.setInputsEnabled(
            source: !hasSearchText,
            filter: !hasSearchText && filter.allowsRefinement
        )
    }

    /// Recomputes the query from both inputs.
    ///
    /// `MoviesQuery` is `Hashable` precisely so a query can be compared. Deleting
    /// typed text back to what is already on screen must not reload it.
    private func applyInputs() {
        updateInputAvailability()

        let query = currentQuery
        guard query != feed.query else { return }
        setQuery(query)
    }

    private func model(for movie: Movie) -> MovieCell.Model {
        MovieCell.Model(
            posterURL: imageURLBuilder.posterURL(path: movie.posterPath),
            title: movie.title,
            year: MovieFormatting.year(movie.releaseDate),
            rating: MovieFormatting.rating(average: movie.voteAverage, count: movie.voteCount),
            isSaved: savedIDs.contains(movie.id)
        )
    }
}
