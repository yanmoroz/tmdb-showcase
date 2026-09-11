import Foundation
import DomainKit
import PresentationKit

/// Seeded with the `Movie` the list already holds, so the screen is never blank:
/// title, artwork, year, rating and overview are on screen before `/movie/{id}`
/// is asked, and the rest appears when it answers.
@MainActor
final class MovieDetailsPresenter {
    weak var view: (any MovieDetailsView)?

    let interactor: any MovieDetailsInteractorInput

    /// `.loading` carries no `Task`, as on the movies screen: the request is the
    /// interactor's.
    private enum Details {
        case idle
        case loading
        case loaded(MovieDetails)
        case failed(AppError)
    }

    private let movie: Movie
    private let imageURLBuilder: any MovieImageURLBuilder

    private var details: Details = .idle
    private var isSaved = false

    init(
        movie: Movie,
        interactor: any MovieDetailsInteractorInput,
        imageURLBuilder: any MovieImageURLBuilder
    ) {
        self.movie = movie
        self.interactor = interactor
        self.imageURLBuilder = imageURLBuilder
    }

    // MARK: - Watchlist

    private func setSaved(_ isSaved: Bool) {
        self.isSaved = isSaved
        view?.setSaved(isSaved)
    }

    // MARK: - Loading

    private func load() {
        details = .loading
        interactor.loadDetails(for: movie.id)
        render()
    }

    // MARK: - Rendering

    private var loadedDetails: MovieDetails? {
        if case .loaded(let details) = details { details } else { nil }
    }

    private func render() {
        view?.show(
            MovieDetailsModel(movie: movie, details: loadedDetails, imageURLBuilder: imageURLBuilder)
        )

        // Additive, never a screen-wide overlay: the seeded content stays on
        // screen while the rest loads or fails.
        switch details {
        case .idle, .loaded:
            view?.hideStatus()
        case .loading:
            view?.showLoading()
        case .failed(let error):
            // Same reasoning as the movies screen: cancellation is not
            // retryable, but retrying is the only move left when nothing
            // arrived.
            view?.showFailure(error.message, retry: error.isRetryable || error == .cancelled)
        }
    }
}

// MARK: - MovieDetailsViewOutput

extension MovieDetailsPresenter: MovieDetailsViewOutput {
    var title: String { movie.title }

    func viewDidLoad() {
        view?.setSaved(isSaved)
        render()
        load()
        interactor.loadSavedIDs()
    }

    func didTapRetry() {
        load()
    }

    /// The seeded `Movie` is what gets saved, so this works before
    /// `/movie/{id}` answers — and offline, where it may never answer.
    func didTapBookmark() {
        let isSaved = !self.isSaved

        setSaved(isSaved)
        interactor.setSaved(isSaved, for: movie)
    }
}

// MARK: - MovieDetailsInteractorOutput

extension MovieDetailsPresenter: MovieDetailsInteractorOutput {
    func didLoadDetails(_ details: MovieDetails) {
        self.details = .loaded(details)
        render()
    }

    func didFailToLoadDetails(with error: AppError) {
        details = .failed(error)
        render()
    }

    func didLoadSavedIDs(_ ids: Set<Movie.ID>) {
        setSaved(ids.contains(movie.id))
    }

    func didFailToSetSaved(_ isSaved: Bool, for id: Movie.ID, with error: AppError) {
        setSaved(!isSaved)
        view?.showToast(error.message)
    }
}
