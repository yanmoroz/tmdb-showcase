import Foundation
import DomainKit

/// What the presenter may ask of the movies screen's business side.
@MainActor
protocol MoviesInteractorInput {
    /// Abandons the load in flight, if any — its outcome is never reported — and
    /// reports this one exactly once.
    func loadPage(_ page: Int, of query: MoviesQuery)
    /// Reports a successful read only.
    func loadSavedIDs()
    /// Reports a failed write only.
    func setSaved(_ isSaved: Bool, for movie: Movie)
}

@MainActor
protocol MoviesInteractorOutput: AnyObject {
    func didLoad(_ page: Page<Movie>)
    func didFailToLoad(with error: AppError)
    func didLoadSavedIDs(_ ids: Set<Movie.ID>)
    func didFailToSetSaved(_ isSaved: Bool, for id: Movie.ID, with error: AppError)
}

/// The use cases behind the movies screen, and the request in flight.
///
/// `output` is `weak`: the presenter owns this.
@MainActor
final class MoviesInteractor: MoviesInteractorInput {
    weak var output: (any MoviesInteractorOutput)?

    private let fetchMovies: any FetchMoviesUseCase
    private let fetchWatchlistIDs: any FetchWatchlistIDsUseCase
    private let addToWatchlist: any AddToWatchlistUseCase
    private let removeFromWatchlist: any RemoveFromWatchlistUseCase

    private var loading: Task<Void, Never>?

    init(
        fetchMovies: any FetchMoviesUseCase,
        fetchWatchlistIDs: any FetchWatchlistIDsUseCase,
        addToWatchlist: any AddToWatchlistUseCase,
        removeFromWatchlist: any RemoveFromWatchlistUseCase
    ) {
        self.fetchMovies = fetchMovies
        self.fetchWatchlistIDs = fetchWatchlistIDs
        self.addToWatchlist = addToWatchlist
        self.removeFromWatchlist = removeFromWatchlist
    }

    deinit {
        loading?.cancel()
    }

    func loadPage(_ page: Int, of query: MoviesQuery) {
        loading?.cancel()

        loading = Task { [weak self, fetchMovies] in
            let outcome: Result<Page<Movie>, AppError>
            do {
                outcome = .success(try await fetchMovies(query: query, page: page))
            } catch let error as AppError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.unknown)
            }

            // Abandoned while the request flew: a newer load owns the answer, and
            // the cancellation flag outlives the suspension.
            guard !Task.isCancelled, let self else { return }

            switch outcome {
            case .success(let result): output?.didLoad(result)
            case .failure(let error): output?.didFailToLoad(with: error)
            }
        }
    }

    func loadSavedIDs() {
        Task { [weak self, fetchWatchlistIDs] in
            // Showing every film as unsaved would be a worse answer to a failed
            // read than the marks already on screen.
            guard let ids = try? await fetchWatchlistIDs() else { return }
            self?.output?.didLoadSavedIDs(ids)
        }
    }

    func setSaved(_ isSaved: Bool, for movie: Movie) {
        Task { [weak self, addToWatchlist, removeFromWatchlist] in
            do {
                if isSaved {
                    try await addToWatchlist(movie)
                } else {
                    try await removeFromWatchlist(id: movie.id)
                }
            } catch let error as AppError {
                self?.output?.didFailToSetSaved(isSaved, for: movie.id, with: error)
            } catch {
                self?.output?.didFailToSetSaved(isSaved, for: movie.id, with: .unknown)
            }
        }
    }
}
