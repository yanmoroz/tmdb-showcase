import UIKit
import DomainKit

final class MoviesViewController: UIViewController {
    private let fetchMovies: any FetchMoviesUseCase
    private let fetchGenres: any FetchGenresUseCase
    /// Held only to hand on: the list never calls it. A router would own this
    /// instead, which is one of the seams the other five architectures change.
    private let fetchMovieDetails: any FetchMovieDetailsUseCase
    /// Three more the list only partly uses, and hands the rest to the screen it
    /// pushes. A router would own them; MVC pays for one in every constructor.
    private let fetchWatchlistIDs: any FetchWatchlistIDsUseCase
    private let addToWatchlist: any AddToWatchlistUseCase
    private let removeFromWatchlist: any RemoveFromWatchlistUseCase
    private let imageURLBuilder: any MovieImageURLBuilder

    /// The accumulated answer to one query.
    ///
    /// `query` is a `let` on purpose: page 3 of `.popular` and page 3 of a search
    /// are different things, so changing the question has to mean building a new
    /// `Feed`. That makes "pages accumulated for a query we are no longer asking"
    /// unrepresentable instead of a reset somebody has to remember.
    private struct Feed {
        let query: MoviesQuery

        private(set) var movies: [Movie] = []
        private(set) var loadedPage = 0
        private(set) var totalPages = 1

        var isEmpty: Bool { movies.isEmpty }
        var count: Int { movies.count }

        /// `nil` once the pages run out.
        var nextPage: Int? { loadedPage < totalPages ? loadedPage + 1 : nil }

        subscript(item: Int) -> Movie { movies[item] }

        func index(of id: Movie.ID) -> Int? {
            movies.firstIndex { $0.id == id }
        }

        mutating func append(_ page: Page<Movie>) {
            movies.append(contentsOf: page.items)
            loadedPage = page.page
            totalPages = page.totalPages
        }
    }

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

    private var feed = Feed(query: .popular) {
        didSet { setNeedsUpdateContentUnavailableConfiguration() }
    }

    private var activity: Activity = .idle {
        didSet { setNeedsUpdateContentUnavailableConfiguration() }
    }

    /// The two independent inputs. `didSet` is what holds the invariant: an input
    /// cannot change without the query being recomputed from both.
    private var searchText: SearchText? { didSet { applyInputs() } }
    private var filter = MoviesFilter() { didSet { applyInputs() } }

    /// Overlaid onto whatever the feed returned — the flag is deliberately not
    /// a field on `Movie`.
    private var savedIDs: Set<Movie.ID> = []

    private var currentQuery: MoviesQuery {
        if let searchText { .search(searchText) } else { filter.query }
    }

    private lazy var collectionView = makeCollectionView()
    private let refreshControl = UIRefreshControl()
    private let searchDebouncer: Debouncer
    private lazy var filterItem = makeFilterItem()
    private lazy var sourceControl = makeSourceControl()

    init(
        fetchMovies: any FetchMoviesUseCase,
        fetchGenres: any FetchGenresUseCase,
        fetchMovieDetails: any FetchMovieDetailsUseCase,
        fetchWatchlistIDs: any FetchWatchlistIDsUseCase,
        addToWatchlist: any AddToWatchlistUseCase,
        removeFromWatchlist: any RemoveFromWatchlistUseCase,
        imageURLBuilder: any MovieImageURLBuilder,
        searchDebounce: Duration = .milliseconds(300)
    ) {
        self.fetchMovies = fetchMovies
        self.fetchGenres = fetchGenres
        self.fetchMovieDetails = fetchMovieDetails
        self.fetchWatchlistIDs = fetchWatchlistIDs
        self.addToWatchlist = addToWatchlist
        self.removeFromWatchlist = removeFromWatchlist
        self.imageURLBuilder = imageURLBuilder
        self.searchDebouncer = Debouncer(interval: searchDebounce)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVC-App builds its UI in code")
    }

    deinit {
        if case .loading(let task) = activity {
            task.cancel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Movies"
        view.backgroundColor = .systemBackground
        setUpSubviews()
        setUpSearch()
        navigationItem.titleView = sourceControl
        navigationItem.rightBarButtonItem = filterItem
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The details screen this list pushed can change what is saved, and
        // there is no channel back — so the list re-reads on the way in.
        reloadWatchlist()
    }

    // MARK: - Watchlist

    private func reloadWatchlist() {
        Task { [weak self] in
            guard let self, let saved = try? await fetchWatchlistIDs(), saved != savedIDs else { return }

            // A read that failed leaves the previous marks alone: showing every
            // film as unsaved would be a worse answer than a slightly old one.
            savedIDs = saved
            collectionView.reloadData()
        }
    }

    /// Optimistic, because the store is local and the answer is nearly instant —
    /// but a failure has to put the mark back, or the reader is left believing a
    /// film is on a list it never reached.
    func toggleWatchlist(for movie: Movie) {
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
                ToastView.show(error.message, in: view)
            } catch {
                setSaved(wasSaved, for: movie.id)
                ToastView.show(AppError.unknown.message, in: view)
            }
        }
    }

    private func setSaved(_ isSaved: Bool, for id: Movie.ID) {
        if isSaved {
            savedIDs.insert(id)
        } else {
            savedIDs.remove(id)
        }

        // One cell, in place. A batch update here would meet the same
        // recount problem `append` documents.
        guard
            let item = feed.index(of: id),
            let cell = collectionView.cellForItem(at: IndexPath(item: item, section: 0)) as? MovieCell
        else { return }
        cell.configure(with: model(for: feed[item]))
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
        collectionView.reloadData()

        // Without this the reader stays at the scroll position of the previous
        // results. `.zero` is not the top: the search bar and safe area push it
        // down by the adjusted inset.
        collectionView.setContentOffset(
            CGPoint(x: 0, y: -collectionView.adjustedContentInset.top),
            animated: false
        )

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
    }

    private func append(_ page: Page<Movie>) {
        refreshControl.endRefreshing()
        feed.append(page)
        activity = .idle

        // reloadData rather than insertItems: a batch update needs the collection
        // view to have recounted itself after the previous reloadData. Between
        // pull-to-refresh and the network response a layout pass may not happen,
        // and insertItems then trips Invalid_Batch_Updates. Content only grows at
        // the end, and reloadData keeps contentOffset.
        collectionView.reloadData()

        // While the page was loading, willDisplay already fired for every cell
        // near the end and found a load in progress. Without this recheck the
        // list stalls at the bottom: no new cells appear, so nothing is left to
        // ask for the next page.
        // Nothing on screen means no reader to run out of items, so a page that
        // came back empty must not pull the next one on its own.
        if let lastVisibleItem {
            loadNextPageIfNearEnd(lastVisibleItem)
        }
    }

    /// `nil` when nothing is on screen — distinct from item 0 being visible.
    private var lastVisibleItem: Int? {
        collectionView.indexPathsForVisibleItems.map(\.item).max()
    }

    private func loadNextPageIfNearEnd(_ item: Int) {
        guard item >= feed.count - Self.loadAheadItems else { return }
        loadNextPage()
    }

    private func handle(_ error: AppError) {
        refreshControl.endRefreshing()

        if feed.isEmpty {
            // Cancellation lands here too: a cancellation that is not followed by
            // a new load — a system one from URLSession, for instance — would
            // otherwise leave the screen with nothing to show and no way out.
            activity = .failed(error)
        } else {
            activity = .idle
            // The list already has content: a page error must not replace it,
            // and a cancellation is not worth reporting at all.
            if error != .cancelled {
                ToastView.show(error.message, in: view)
            }
        }
    }

    // MARK: - Unavailable content

    override func updateContentUnavailableConfiguration(
        using state: UIContentUnavailableConfigurationState
    ) {
        // Derived from the two axes rather than assigned by hand: an overlay
        // cannot cover a non-empty list, because every branch that produces one
        // requires an empty feed.
        contentUnavailableConfiguration = switch activity {
        case .loading where feed.isEmpty: UIContentUnavailableConfiguration.loading()
        case .failed(let error): failureConfiguration(error)
        case .idle where feed.isEmpty: emptyResultsConfiguration()
        default: nil
        }
    }

    private func emptyResultsConfiguration() -> UIContentUnavailableConfiguration {
        // The first-party search preset writes its own text, localised to the
        // device — the reason a bespoke empty-state view was dropped earlier.
        if case .search = feed.query {
            UIContentUnavailableConfiguration.search()
        } else {
            emptyConfiguration()
        }
    }

    private func emptyConfiguration() -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "film")
        configuration.text = "No movies"
        configuration.secondaryText = "Nothing to show here."
        return configuration
    }

    private func failureConfiguration(_ error: AppError) -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "Couldn't load"
        configuration.secondaryText = error.message

        // Cancellation is not transient, so isRetryable leaves it out. Retrying
        // is still the only useful action left: nothing was loaded.
        if error.isRetryable || error == .cancelled {
            var button = UIButton.Configuration.borderless()
            button.title = "Retry"
            configuration.button = button
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                self?.reload()
            }
        }
        return configuration
    }

    // MARK: - Search

    private func setUpSearch() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        // Results are drawn in the same list, so dimming it on focus would hide
        // the very thing the search is filtering.
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search movies"
        // Film titles are proper nouns in every language TMDB carries, so the
        // keyboard must not second-guess them.
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    private func applySearch(_ input: String) {
        // The failable init of SearchText *is* the "blank input is no reason to
        // hit the network" rule: nil means fall back to whatever the filter says.
        searchText = SearchText(input)
    }

    /// Recomputes the query from both inputs.
    ///
    /// MoviesQuery is Hashable precisely so a query can be compared. Deleting
    /// typed text back to what is already on screen must not reload it.
    private func applyInputs() {
        updateInputAvailability()

        let query = currentQuery
        guard query != feed.query else { return }
        setQuery(query)
    }

    // MARK: - Filter

    /// A search overrides both, and `/trending` accepts neither genre nor sort,
    /// so under either the controls would be there to do nothing.
    ///
    /// Read from the field rather than from `searchText`, which the debounce
    /// leaves a beat behind: in that window the controls would still be live over
    /// a search that is about to start, and using them would do nothing.
    private func updateInputAvailability() {
        let hasSearchText = SearchText(navigationItem.searchController?.searchBar.text ?? "") != nil

        sourceControl.isEnabled = !hasSearchText
        filterItem.isEnabled = !hasSearchText && filter.allowsRefinement
    }

    private func makeSourceControl() -> UISegmentedControl {
        let sources = MoviesFilter.Source.allCases
        let control = UISegmentedControl(items: sources.map(\.title))
        control.selectedSegmentIndex = sources.firstIndex(of: filter.source) ?? 0

        control.addAction(
            UIAction { [weak self, weak control] _ in
                guard let control, control.selectedSegmentIndex != UISegmentedControl.noSegment else { return }
                self?.filter.source = sources[control.selectedSegmentIndex]
            },
            for: .valueChanged
        )
        return control
    }

    private func makeFilterItem() -> UIBarButtonItem {
        UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            primaryAction: UIAction { [weak self] _ in self?.presentFilter() }
        )
    }

    private func presentFilter() {
        guard presentedViewController == nil else { return }

        let filterViewController = MoviesFilterViewController(
            fetchGenres: fetchGenres,
            selection: filter
        ) { [weak self] filter in
            self?.applyFilter(filter)
        }

        present(UINavigationController(rootViewController: filterViewController), animated: true)
    }

    /// The filter screen's callback, named rather than inlined so it is reachable
    /// without standing up a modal in a windowless test. Internal for that reason
    /// alone — everything else about the filter stays private.
    func applyFilter(_ filter: MoviesFilter) {
        self.filter = filter
    }

    // MARK: - Details

    /// Pushed by this controller, as the filter is presented by it. The guard is
    /// the push form of `presentFilter`'s: two quick taps would otherwise stack
    /// two copies of the same screen.
    func showDetails(for movie: Movie) {
        guard navigationController?.topViewController === self else { return }

        navigationController?.pushViewController(
            MovieDetailsViewController(
                movie: movie,
                fetchDetails: fetchMovieDetails,
                fetchWatchlistIDs: fetchWatchlistIDs,
                addToWatchlist: addToWatchlist,
                removeFromWatchlist: removeFromWatchlist,
                imageURLBuilder: imageURLBuilder
            ),
            animated: true
        )
    }

    // MARK: - Layout

    private func setUpSubviews() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeCollectionView() -> UICollectionView {
        let collectionView = MovieGrid.makeCollectionView()
        collectionView.dataSource = self
        collectionView.delegate = self
        return collectionView
    }

    @objc private func refreshTriggered() {
        reload()
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

// MARK: - UICollectionViewDataSource

extension MoviesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        feed.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MovieCell.reuseIdentifier,
            for: indexPath
        )
        let movie = feed[indexPath.item]
        if let cell = cell as? MovieCell {
            cell.configure(with: model(for: movie))
            cell.onToggleWatchlist = { [weak self] in self?.toggleWatchlist(for: movie) }
        }
        return cell
    }
}

// MARK: - UISearchResultsUpdating

extension MoviesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let input = searchController.searchBar.text ?? ""
        updateInputAvailability()

        searchDebouncer.schedule { [weak self] in
            self?.applySearch(input)
        }
    }
}

// MARK: - UICollectionViewDelegate

extension MoviesViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        loadNextPageIfNearEnd(indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        showDetails(for: feed[indexPath.item])
    }
}
