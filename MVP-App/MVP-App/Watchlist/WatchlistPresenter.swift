import Foundation
import DomainKit
import PresentationKit

/// The films the reader saved, newest first.
///
/// Everything listed here is saved, so the cell's bookmark is always filled and
/// tapping one un-saves.
@MainActor
final class WatchlistPresenter {
    weak var view: (any WatchlistView)?

    private enum Saved {
        case idle
        case loading(Task<Void, Never>)
        case loaded([Movie])
        case failed(AppError)
    }

    private let fetchWatchlist: any FetchWatchlistUseCase
    private let addToWatchlist: any AddToWatchlistUseCase
    private let removeFromWatchlist: any RemoveFromWatchlistUseCase
    private let imageURLBuilder: any MovieImageURLBuilder

    private var saved: Saved = .idle

    /// Un-saving leaves the row in place until the next appearance, so which
    /// films are still saved has to be tracked apart from which are listed.
    private var savedIDs: Set<Movie.ID> = []

    private var movies: [Movie] {
        if case .loaded(let movies) = saved { movies } else { [] }
    }

    init(
        fetchWatchlist: any FetchWatchlistUseCase,
        addToWatchlist: any AddToWatchlistUseCase,
        removeFromWatchlist: any RemoveFromWatchlistUseCase,
        imageURLBuilder: any MovieImageURLBuilder
    ) {
        self.fetchWatchlist = fetchWatchlist
        self.addToWatchlist = addToWatchlist
        self.removeFromWatchlist = removeFromWatchlist
        self.imageURLBuilder = imageURLBuilder
    }

    deinit {
        if case .loading(let task) = saved {
            task.cancel()
        }
    }

    // MARK: - Lifecycle

    func viewWillAppear() {
        // Saving happens on the other tab and on the details screen, and there is
        // no channel back — so the list is re-read every time it appears.
        load()
    }

    // MARK: - Input

    func didTapRetry() {
        load()
    }

    func didSelectItem(at index: Int) {
        guard movies.indices.contains(index) else { return }
        view?.showDetails(for: movies[index])
    }

    /// Un-saving does not drop the row: the mark empties and the film goes on the
    /// next appearance. A mis-tap is then undone in place, and nothing has to
    /// reconcile a delete against a grid being scrolled.
    func didToggleWatchlist(at index: Int) {
        guard movies.indices.contains(index) else { return }
        let movie = movies[index]
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

    private func setSaved(_ isSaved: Bool, for id: Movie.ID) {
        if isSaved {
            savedIDs.insert(id)
        } else {
            savedIDs.remove(id)
        }

        guard let item = movies.firstIndex(where: { $0.id == id }) else { return }
        view?.updateItem(at: item, with: model(for: movies[item]))
    }

    // MARK: - Loading

    private func load() {
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
                render()
            }
        )
        render()
    }

    // MARK: - Rendering

    private func render() {
        view?.show(movies.map(model(for:)))

        switch saved {
        case .loading where movies.isEmpty:
            view?.showLoading()
        case .failed(let error):
            view?.showFailure(error.message, retry: error.isRetryable)
        case .loaded(let movies) where movies.isEmpty:
            view?.showEmpty()
        default:
            view?.hideOverlay()
        }
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
