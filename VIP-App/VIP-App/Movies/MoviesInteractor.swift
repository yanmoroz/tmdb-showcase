import Foundation
import DomainKit
import PresentationKit

@MainActor
protocol MoviesBusinessLogic {
    func start(_ request: MoviesModels.Request.Start)
    func reload(_ request: MoviesModels.Request.Reload)
    func reloadSavedIDs(_ request: MoviesModels.Request.ReloadSavedIDs)

    func changeSearchText(_ request: MoviesModels.Request.ChangeSearchText)
    func changeSource(_ request: MoviesModels.Request.ChangeSource)
    func applyFilter(_ request: MoviesModels.Request.ApplyFilter)

    func willDisplayItem(_ request: MoviesModels.Request.WillDisplayItem)
    func toggleWatchlist(_ request: MoviesModels.Request.ToggleWatchlist)
    func selectMovie(_ request: MoviesModels.Request.SelectMovie)
}

/// What the router may read on its way somewhere.
@MainActor
protocol MoviesDataStore: AnyObject {
    var filter: MoviesFilter { get }
    var selectedMovie: Movie? { get }
}

/// Everything the movies screen knows, and the request in flight.
@MainActor
final class MoviesInteractor: MoviesBusinessLogic, MoviesDataStore {
    let presenter: any MoviesPresentationLogic

    private let fetchMovies: any FetchMoviesUseCase
    private let fetchWatchlistIDs: any FetchWatchlistIDsUseCase
    private let addToWatchlist: any AddToWatchlistUseCase
    private let removeFromWatchlist: any RemoveFromWatchlistUseCase

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
    private(set) var filter = MoviesFilter() { didSet { applyInputs() } }

    /// The raw field contents, which the debounce leaves `searchText` a beat
    /// behind. Availability is read from here so the controls are never live over
    /// a search that is about to start.
    private var typedSearch = ""

    /// Overlaid onto whatever the feed returned — the flag is deliberately not
    /// a field on `Movie`.
    private var savedIDs: Set<Movie.ID> = []

    private(set) var selectedMovie: Movie?

    private let searchDebouncer: Debouncer

    private var currentQuery: MoviesQuery {
        if let searchText { .search(searchText) } else { filter.query }
    }

    init(
        presenter: any MoviesPresentationLogic,
        fetchMovies: any FetchMoviesUseCase,
        fetchWatchlistIDs: any FetchWatchlistIDsUseCase,
        addToWatchlist: any AddToWatchlistUseCase,
        removeFromWatchlist: any RemoveFromWatchlistUseCase,
        searchDebounce: Duration = .milliseconds(300)
    ) {
        self.presenter = presenter
        self.fetchMovies = fetchMovies
        self.fetchWatchlistIDs = fetchWatchlistIDs
        self.addToWatchlist = addToWatchlist
        self.removeFromWatchlist = removeFromWatchlist
        self.searchDebouncer = Debouncer(interval: searchDebounce)
    }

    deinit {
        if case .loading(let task) = activity {
            task.cancel()
        }
    }

    // MARK: - MoviesBusinessLogic

    func start(_ request: MoviesModels.Request.Start) {
        presentInputAvailability()
        reloadFeed()
    }

    func reload(_ request: MoviesModels.Request.Reload) {
        reloadFeed()
    }

    func reloadSavedIDs(_ request: MoviesModels.Request.ReloadSavedIDs) {
        // The details screen this list pushes can change what is saved, and
        // there is no channel back — so the list re-reads on the way in.
        Task { [weak self] in
            guard let self, let saved = try? await fetchWatchlistIDs(), saved != savedIDs else { return }

            // A read that failed leaves the previous marks alone: showing every
            // film as unsaved would be a worse answer than a slightly old one.
            savedIDs = saved
            presentFeed()
        }
    }

    func changeSearchText(_ request: MoviesModels.Request.ChangeSearchText) {
        typedSearch = request.text
        presentInputAvailability()

        searchDebouncer.schedule { [weak self] in
            // The failable init of SearchText *is* the "blank input is no reason
            // to hit the network" rule: nil means fall back to the filter.
            self?.searchText = SearchText(request.text)
        }
    }

    func changeSource(_ request: MoviesModels.Request.ChangeSource) {
        filter.source = request.source
    }

    func applyFilter(_ request: MoviesModels.Request.ApplyFilter) {
        filter = request.filter
    }

    func willDisplayItem(_ request: MoviesModels.Request.WillDisplayItem) {
        loadNextPageIfNearEnd(request.index)
    }

    func toggleWatchlist(_ request: MoviesModels.Request.ToggleWatchlist) {
        guard feed.movies.indices.contains(request.index) else { return }
        let movie = feed[request.index]
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
                presenter.presentWriteFailure(.init(error: error))
            } catch {
                setSaved(wasSaved, for: movie.id)
                presenter.presentWriteFailure(.init(error: .unknown))
            }
        }
    }

    func selectMovie(_ request: MoviesModels.Request.SelectMovie) {
        guard feed.movies.indices.contains(request.index) else { return }
        selectedMovie = feed[request.index]
        presenter.presentMovieSelection(.init())
    }

    // MARK: - Watchlist

    private func setSaved(_ isSaved: Bool, for id: Movie.ID) {
        if isSaved {
            savedIDs.insert(id)
        } else {
            savedIDs.remove(id)
        }

        guard let index = feed.index(of: id) else { return }
        presenter.presentItem(.init(index: index, movie: feed[index], isSaved: isSaved))
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
        presentFeed()
        presenter.presentScrollToTop(.init())

        loadNextPage()
    }

    private func reloadFeed() {
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
        presentOverlay()
    }

    private func append(_ page: Page<Movie>) {
        presenter.presentRefreshEnded(.init())
        feed.append(page)
        activity = .idle
        presentFeed()
    }

    private func loadNextPageIfNearEnd(_ index: Int) {
        guard index >= feed.count - Self.loadAheadItems else { return }
        loadNextPage()
    }

    private func handle(_ error: AppError) {
        presenter.presentRefreshEnded(.init())

        if feed.isEmpty {
            // Cancellation lands here too: a cancellation that is not followed by
            // a new load — a system one from URLSession, for instance — would
            // otherwise leave the screen with nothing to show and no way out.
            activity = .failed(error)
            presentOverlay()
        } else {
            activity = .idle
            presentOverlay()
            presenter.presentLaterPageFailure(.init(error: error))
        }
    }

    // MARK: - Presenting

    private func presentFeed() {
        presenter.presentFeed(.init(movies: feed.movies, savedIDs: savedIDs))
        presentOverlay()
    }

    private func presentOverlay() {
        let current: MoviesModels.Response.Overlay.Activity = switch activity {
        case .idle: .idle
        case .loading: .loading
        case .failed(let error): .failed(error)
        }
        presenter.presentOverlay(.init(activity: current, isEmpty: feed.isEmpty, isSearching: isSearching))
    }

    private var isSearching: Bool {
        if case .search = feed.query { true } else { false }
    }

    private func presentInputAvailability() {
        presenter.presentInputAvailability(
            .init(hasSearchText: SearchText(typedSearch) != nil, allowsRefinement: filter.allowsRefinement)
        )
    }

    /// Recomputes the query from both inputs.
    ///
    /// `MoviesQuery` is `Hashable` precisely so a query can be compared. Deleting
    /// typed text back to what is already on screen must not reload it.
    private func applyInputs() {
        presentInputAvailability()

        let query = currentQuery
        guard query != feed.query else { return }
        setQuery(query)
    }
}
