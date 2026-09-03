import UIKit
import DomainKit

/// The films the reader saved, newest first.
///
/// The same grid and the same `MovieCell` as the movies list: everything here is
/// saved, so the cell's bookmark is simply always filled and tapping it un-saves.
final class WatchlistViewController: UIViewController {
    private enum Saved {
        case idle
        case loading(Task<Void, Never>)
        case loaded([Movie])
        case failed(AppError)
    }

    private let fetchWatchlist: any FetchWatchlistUseCase
    /// The next three are held only to hand to the details screen this one
    /// pushes — the same pass-through the movies list already pays for.
    private let fetchMovieDetails: any FetchMovieDetailsUseCase
    private let fetchWatchlistIDs: any FetchWatchlistIDsUseCase
    private let addToWatchlist: any AddToWatchlistUseCase
    private let removeFromWatchlist: any RemoveFromWatchlistUseCase
    private let imageURLBuilder: any MovieImageURLBuilder

    private var saved: Saved = .idle {
        didSet {
            setNeedsUpdateContentUnavailableConfiguration()
            collectionView.reloadData()
        }
    }

    /// Un-saving leaves the row in place until the next appearance, so which
    /// films are still saved has to be tracked apart from which are listed.
    private var savedIDs: Set<Movie.ID> = []

    private lazy var collectionView = makeCollectionView()

    private var movies: [Movie] {
        if case .loaded(let movies) = saved { movies } else { [] }
    }

    init(
        fetchWatchlist: any FetchWatchlistUseCase,
        fetchMovieDetails: any FetchMovieDetailsUseCase,
        fetchWatchlistIDs: any FetchWatchlistIDsUseCase,
        addToWatchlist: any AddToWatchlistUseCase,
        removeFromWatchlist: any RemoveFromWatchlistUseCase,
        imageURLBuilder: any MovieImageURLBuilder
    ) {
        self.fetchWatchlist = fetchWatchlist
        self.fetchMovieDetails = fetchMovieDetails
        self.fetchWatchlistIDs = fetchWatchlistIDs
        self.addToWatchlist = addToWatchlist
        self.removeFromWatchlist = removeFromWatchlist
        self.imageURLBuilder = imageURLBuilder
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVC-App builds its UI in code")
    }

    deinit {
        if case .loading(let task) = saved {
            task.cancel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Watchlist"
        view.backgroundColor = .systemBackground
        setUpSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Saving happens on the other tab and on the details screen, and there is
        // no channel back — so the list is re-read every time it appears.
        load()
    }

    // MARK: - Loading

    func load() {
        if case .loading(let task) = saved {
            task.cancel()
        }

        saved = .loading(
            Task { [weak self] in
                guard let self else { return }

                let outcome: Result<[Movie], AppError>
                do {
                    outcome = .success(try await fetchWatchlist())
                } catch let error as AppError {
                    outcome = .failure(error)
                } catch {
                    outcome = .failure(.unknown)
                }

                guard !Task.isCancelled else { return }

                switch outcome {
                case .success(let movies):
                    savedIDs = Set(movies.map(\.id))
                    saved = .loaded(movies)
                case .failure(let error):
                    saved = .failed(error)
                }
            }
        )
    }

    // MARK: - Watchlist

    /// Un-saving does not drop the row: the mark empties and the film goes on the
    /// next appearance. A mis-tap is then undone in place, and nothing has to
    /// reconcile a delete against a grid being scrolled.
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

        guard
            let item = movies.firstIndex(where: { $0.id == id }),
            let cell = collectionView.cellForItem(at: IndexPath(item: item, section: 0)) as? MovieCell
        else { return }
        cell.configure(with: model(for: movies[item]))
    }

    // MARK: - Details

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

    // MARK: - Unavailable content

    override func updateContentUnavailableConfiguration(
        using state: UIContentUnavailableConfigurationState
    ) {
        contentUnavailableConfiguration = switch saved {
        case .loading where movies.isEmpty: UIContentUnavailableConfiguration.loading()
        case .failed(let error): failureConfiguration(error)
        case .loaded(let movies) where movies.isEmpty: emptyConfiguration()
        default: nil
        }
    }

    private func emptyConfiguration() -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "bookmark")
        configuration.text = "Nothing saved yet"
        configuration.secondaryText = "Bookmark a film and it turns up here."
        return configuration
    }

    private func failureConfiguration(_ error: AppError) -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "Couldn't load"
        configuration.secondaryText = error.message

        if error.isRetryable {
            var button = UIButton.Configuration.borderless()
            button.title = "Retry"
            configuration.button = button
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                self?.load()
            }
        }
        return configuration
    }

    // MARK: - Layout

    private func setUpSubviews() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

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

extension WatchlistViewController: UICollectionViewDataSource {
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
        let movie = movies[indexPath.item]
        if let cell = cell as? MovieCell {
            cell.configure(with: model(for: movie))
            cell.onToggleWatchlist = { [weak self] in self?.toggleWatchlist(for: movie) }
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension WatchlistViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        showDetails(for: movies[indexPath.item])
    }
}
