import Foundation
import DomainKit

@MainActor
protocol MovieDetailsInteractorInput {
    /// Abandons the load in flight, if any — its outcome is never reported — and
    /// reports this one exactly once.
    func loadDetails(for id: Movie.ID)
    /// Reports a successful read only.
    func loadSavedIDs()
    /// Reports a failed write only.
    func setSaved(_ isSaved: Bool, for movie: Movie)
}

@MainActor
protocol MovieDetailsInteractorOutput: AnyObject {
    func didLoadDetails(_ details: MovieDetails)
    func didFailToLoadDetails(with error: AppError)
    func didLoadSavedIDs(_ ids: Set<Movie.ID>)
    func didFailToSetSaved(_ isSaved: Bool, for id: Movie.ID, with error: AppError)
}

/// The use cases behind the details screen, and the request in flight.
///
/// `output` is `weak`: the presenter owns this.
@MainActor
final class MovieDetailsInteractor: MovieDetailsInteractorInput {
    weak var output: (any MovieDetailsInteractorOutput)?

    private let fetchDetails: any FetchMovieDetailsUseCase
    private let fetchWatchlistIDs: any FetchWatchlistIDsUseCase
    private let addToWatchlist: any AddToWatchlistUseCase
    private let removeFromWatchlist: any RemoveFromWatchlistUseCase

    private var loading: Task<Void, Never>?

    init(
        fetchDetails: any FetchMovieDetailsUseCase,
        fetchWatchlistIDs: any FetchWatchlistIDsUseCase,
        addToWatchlist: any AddToWatchlistUseCase,
        removeFromWatchlist: any RemoveFromWatchlistUseCase
    ) {
        self.fetchDetails = fetchDetails
        self.fetchWatchlistIDs = fetchWatchlistIDs
        self.addToWatchlist = addToWatchlist
        self.removeFromWatchlist = removeFromWatchlist
    }

    deinit {
        loading?.cancel()
    }

    func loadDetails(for id: Movie.ID) {
        loading?.cancel()

        loading = Task { [weak self, fetchDetails] in
            let outcome: Result<MovieDetails, AppError>
            do {
                outcome = .success(try await fetchDetails(id: id))
            } catch let error as AppError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.unknown)
            }

            // Abandoned while the request flew: a newer load owns the answer.
            guard !Task.isCancelled, let self else { return }

            switch outcome {
            case .success(let details): output?.didLoadDetails(details)
            case .failure(let error): output?.didFailToLoadDetails(with: error)
            }
        }
    }

    func loadSavedIDs() {
        Task { [weak self, fetchWatchlistIDs] in
            // Showing the film as unsaved would be a worse answer to a failed read
            // than the bookmark already on screen.
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
