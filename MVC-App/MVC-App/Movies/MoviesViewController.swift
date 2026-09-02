import UIKit
import DomainKit
import DataKit

final class MoviesViewController: UIViewController {
    private let fetchMovies: any FetchMoviesUseCase
    private let imageURLBuilder: TMDBImageURLBuilder

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

    private lazy var collectionView = makeCollectionView()
    private let refreshControl = UIRefreshControl()
    private let searchDebouncer: Debouncer

    init(
        fetchMovies: any FetchMoviesUseCase,
        imageURLBuilder: TMDBImageURLBuilder,
        searchDebounce: Duration = .milliseconds(300)
    ) {
        self.fetchMovies = fetchMovies
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
        title = "Фильмы"
        view.backgroundColor = .systemBackground
        setUpSubviews()
        setUpSearch()
        reload()
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
        configuration.text = "Фильмов нет"
        configuration.secondaryText = "TMDB не вернул ни одной записи."
        return configuration
    }

    private func failureConfiguration(_ error: AppError) -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "Не удалось загрузить"
        configuration.secondaryText = error.message

        // Cancellation is not transient, so isRetryable leaves it out. Retrying
        // is still the only useful action left: nothing was loaded.
        if error.isRetryable || error == .cancelled {
            var button = UIButton.Configuration.borderless()
            button.title = "Повторить"
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
        searchController.searchBar.placeholder = "Поиск фильмов"
        // Film titles are proper nouns in every language TMDB carries, so the
        // keyboard must not second-guess them.
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    private func applySearch(_ input: String) {
        // The failable init of SearchText *is* the "blank input is no reason to
        // hit the network" rule: nil means fall back to popular.
        let query: MoviesQuery = SearchText(input).map { .search($0) } ?? .popular

        // MoviesQuery is Hashable precisely so a query can be compared. Deleting
        // typed text back to what is already on screen must not reload it.
        guard query != feed.query else { return }
        setQuery(query)
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
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0 / 3.0),
                heightDimension: .fractionalHeight(1)
            )
        )
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)

        // The group height is a fraction of the width, so posters keep their 2:3
        // ratio at any screen width without recomputing anything in code.
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalWidth(0.62)
            ),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 10, bottom: 16, trailing: 10)

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: UICollectionViewCompositionalLayout(section: section)
        )
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.register(MovieCell.self, forCellWithReuseIdentifier: MovieCell.reuseIdentifier)
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
            year: movie.releaseDate.map { Self.yearFormatter.string(from: $0) },
            rating: movie.voteCount > 0 ? String(format: "★ %.1f", movie.voteAverage) : nil
        )
    }

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter
    }()
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
        (cell as? MovieCell)?.configure(with: model(for: feed[indexPath.item]))
        return cell
    }
}

// MARK: - UISearchResultsUpdating

extension MoviesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let input = searchController.searchBar.text ?? ""
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
}
