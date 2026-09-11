import Foundation
import DomainKit

@MainActor
protocol WatchlistInteractorInput {
    /// Abandons the load in flight, if any — its outcome is never reported — and
    /// reports this one exactly once.
    func loadWatchlist()
    /// Reports a failed write only.
    func setSaved(_ isSaved: Bool, for movie: Movie)
}

@MainActor
protocol WatchlistInteractorOutput: AnyObject {
    func didLoadWatchlist(_ movies: [Movie])
    func didFailToLoadWatchlist(with error: AppError)
    func didFailToSetSaved(_ isSaved: Bool, for id: Movie.ID, with error: AppError)
}

/// The saved films behind the watchlist tab, and the read in flight.
///
/// `output` is `weak`: the presenter owns this.
@MainActor
final class WatchlistInteractor: WatchlistInteractorInput {
    weak var output: (any WatchlistInteractorOutput)?

    private let fetchWatchlist: any FetchWatchlistUseCase
    private let addToWatchlist: any AddToWatchlistUseCase
    private let removeFromWatchlist: any RemoveFromWatchlistUseCase

    private var loading: Task<Void, Never>?

    init(
        fetchWatchlist: any FetchWatchlistUseCase,
        addToWatchlist: any AddToWatchlistUseCase,
        removeFromWatchlist: any RemoveFromWatchlistUseCase
    ) {
        self.fetchWatchlist = fetchWatchlist
        self.addToWatchlist = addToWatchlist
        self.removeFromWatchlist = removeFromWatchlist
    }

    deinit {
        loading?.cancel()
    }

    func loadWatchlist() {
        loading?.cancel()

        loading = Task { [weak self, fetchWatchlist] in
            let outcome: Result<[Movie], AppError>
            do {
                outcome = .success(try await fetchWatchlist())
            } catch let error as AppError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.unknown)
            }

            // Abandoned while the read was in flight: a newer load owns the answer.
            guard !Task.isCancelled, let self else { return }

            switch outcome {
            case .success(let movies): output?.didLoadWatchlist(movies)
            case .failure(let error): output?.didFailToLoadWatchlist(with: error)
            }
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
