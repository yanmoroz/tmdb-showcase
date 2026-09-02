import UIKit
import DomainKit
import DataKit

final class MoviesViewController: UIViewController {
    private let fetchMovies: any FetchMoviesUseCase
    private let imageURLBuilder: TMDBImageURLBuilder
    private let query: MoviesQuery = .popular

    private enum ScreenState {
        case loading
        case loaded
        case failed(AppError)
    }

    /// Two rows short of the end.
    private static let loadAheadItems = 6

    private var movies: [Movie] = []
    private var loadedPage = 0
    private var totalPages = 1
    private var loadTask: Task<Void, Never>?
    /// Bumped by every reload so an in-flight task can tell it is stale.
    private var loadGeneration = 0

    private var screenState: ScreenState = .loading {
        didSet { setNeedsUpdateContentUnavailableConfiguration() }
    }

    private lazy var collectionView = makeCollectionView()
    private let refreshControl = UIRefreshControl()

    init(fetchMovies: any FetchMoviesUseCase, imageURLBuilder: TMDBImageURLBuilder) {
        self.fetchMovies = fetchMovies
        self.imageURLBuilder = imageURLBuilder
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVC-App builds its UI in code")
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Фильмы"
        view.backgroundColor = .systemBackground
        setUpSubviews()
        reload()
    }

    // MARK: - Loading

    private func reload() {
        // Clearing the reference matters as much as cancelling: cancel() only
        // raises a flag, and loadNextPage() below refuses to start while
        // loadTask is non-nil.
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1

        loadedPage = 0
        totalPages = 1
        movies = []
        collectionView.reloadData()
        screenState = .loading
        loadNextPage()
    }

    private func loadNextPage() {
        guard loadTask == nil, loadedPage < totalPages else { return }

        let page = loadedPage + 1
        let generation = loadGeneration
        loadTask = Task { [weak self] in
            guard let self else { return }
            // Only the current generation owns loadTask; a stale task clearing it
            // would let a duplicate request for the same page start.
            defer { if generation == loadGeneration { loadTask = nil } }

            let outcome: Result<Page<Movie>, AppError>
            do {
                outcome = .success(try await fetchMovies(query: query, page: page))
            } catch let error as AppError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.unknown)
            }

            // reload() may have started a new generation while the request flew.
            guard generation == loadGeneration else { return }

            switch outcome {
            case .success(let result): append(result)
            case .failure(let error): handle(error)
            }
        }
    }

    private func append(_ page: Page<Movie>) {
        refreshControl.endRefreshing()

        loadedPage = page.page
        totalPages = page.totalPages
        movies.append(contentsOf: page.items)

        // reloadData rather than insertItems: a batch update needs the collection
        // view to have recounted itself after the previous reloadData. Between
        // pull-to-refresh and the network response a layout pass may not happen,
        // and insertItems then trips Invalid_Batch_Updates. Content only grows at
        // the end, and reloadData keeps contentOffset.
        collectionView.reloadData()
        screenState = .loaded

        // While the page was loading, willDisplay already fired for every cell
        // near the end and hit a busy loadTask. Without this recheck the list
        // stalls at the bottom: no new cells appear, so nothing is left to ask
        // for the next page.
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
        guard item >= movies.count - Self.loadAheadItems else { return }
        loadNextPage()
    }

    private func handle(_ error: AppError) {
        refreshControl.endRefreshing()

        if movies.isEmpty {
            // Cancellation lands here too. `.loading` has no exit of its own, so
            // leaving the state untouched would strand the screen on a spinner
            // whenever a cancellation is not followed by a new load — a system
            // cancellation from URLSession, for one.
            screenState = .failed(error)
        } else if error != .cancelled {
            // The list already has content: a page error must not replace it,
            // and a cancellation is not worth reporting at all.
            ToastView.show(error.message, in: view)
        }
    }

    // MARK: - Unavailable content

    override func updateContentUnavailableConfiguration(
        using state: UIContentUnavailableConfigurationState
    ) {
        switch screenState {
        case .loading:
            contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()

        case .loaded:
            // An overlay over a non-empty list would lie: the page did arrive.
            contentUnavailableConfiguration = movies.isEmpty ? emptyConfiguration() : nil

        case .failed(let error):
            contentUnavailableConfiguration = failureConfiguration(error)
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
        movies.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MovieCell.reuseIdentifier,
            for: indexPath
        )
        (cell as? MovieCell)?.configure(with: model(for: movies[indexPath.item]))
        return cell
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
