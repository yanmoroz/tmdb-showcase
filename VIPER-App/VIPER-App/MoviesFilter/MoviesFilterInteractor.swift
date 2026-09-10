import Foundation
import DomainKit

@MainActor
protocol MoviesFilterInteractorInput {
    /// Abandons the load in flight, if any — its outcome is never reported — and
    /// reports this one exactly once.
    func loadGenres()
}

@MainActor
protocol MoviesFilterInteractorOutput: AnyObject {
    func didLoadGenres(_ genres: [Genre])
    func didFailToLoadGenres(with error: AppError)
}

/// The genre catalogue behind the filter sheet, and the request in flight.
///
/// `output` is `weak`: the presenter owns this.
@MainActor
final class MoviesFilterInteractor: MoviesFilterInteractorInput {
    weak var output: (any MoviesFilterInteractorOutput)?

    private let fetchGenres: any FetchGenresUseCase

    private var loading: Task<Void, Never>?

    init(fetchGenres: any FetchGenresUseCase) {
        self.fetchGenres = fetchGenres
    }

    deinit {
        loading?.cancel()
    }

    func loadGenres() {
        loading?.cancel()

        loading = Task { [weak self, fetchGenres] in
            let outcome: Result<[Genre], AppError>
            do {
                outcome = .success(try await fetchGenres())
            } catch let error as AppError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.unknown)
            }

            // Abandoned while the request flew: a newer load owns the answer.
            guard !Task.isCancelled, let self else { return }

            switch outcome {
            case .success(let genres): output?.didLoadGenres(genres)
            case .failure(let error): output?.didFailToLoadGenres(with: error)
            }
        }
    }
}
