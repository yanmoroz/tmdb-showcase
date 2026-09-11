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

    let interactor: any WatchlistInteractorInput
    let router: any WatchlistRouterInput

    /// `.loading` carries no `Task`, as on the other screens: the read is the
    /// interactor's.
    private enum Saved {
        case idle
        case loading
        case loaded([Movie])
        case failed(AppError)
    }

    private let imageURLBuilder: any MovieImageURLBuilder

    private var saved: Saved = .idle

    /// Un-saving leaves the row in place until the next appearance, so which
    /// films are still saved has to be tracked apart from which are listed.
    private var savedIDs: Set<Movie.ID> = []

    private var movies: [Movie] {
        if case .loaded(let movies) = saved { movies } else { [] }
    }

    init(
        interactor: any WatchlistInteractorInput,
        router: any WatchlistRouterInput,
        imageURLBuilder: any MovieImageURLBuilder
    ) {
        self.interactor = interactor
        self.router = router
        self.imageURLBuilder = imageURLBuilder
    }

    // MARK: - Watchlist

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
        saved = .loading
        interactor.loadWatchlist()
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

// MARK: - WatchlistViewOutput

extension WatchlistPresenter: WatchlistViewOutput {
    func viewWillAppear() {
        // Saving happens on the other tab and on the details screen, and there is
        // no channel back — so the list is re-read every time it appears.
        load()
    }

    func didTapRetry() {
        load()
    }

    func didSelectItem(at index: Int) {
        guard movies.indices.contains(index) else { return }
        router.showDetails(for: movies[index])
    }

    /// Un-saving does not drop the row: the mark empties and the film goes on the
    /// next appearance. A mis-tap is then undone in place, and nothing has to
    /// reconcile a delete against a grid being scrolled.
    func didToggleWatchlist(at index: Int) {
        guard movies.indices.contains(index) else { return }
        let movie = movies[index]
        let isSaved = !savedIDs.contains(movie.id)

        setSaved(isSaved, for: movie.id)
        interactor.setSaved(isSaved, for: movie)
    }
}

// MARK: - WatchlistInteractorOutput

extension WatchlistPresenter: WatchlistInteractorOutput {
    func didLoadWatchlist(_ movies: [Movie]) {
        savedIDs = Set(movies.map(\.id))
        saved = .loaded(movies)
        render()
    }

    func didFailToLoadWatchlist(with error: AppError) {
        saved = .failed(error)
        render()
    }

    func didFailToSetSaved(_ isSaved: Bool, for id: Movie.ID, with error: AppError) {
        setSaved(!isSaved, for: id)
        view?.showToast(error.message)
    }
}
