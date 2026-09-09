import Foundation
import DomainKit
import PresentationKit

/// Seeded with the `Movie` the list already holds, so the screen is never blank:
/// title, artwork, year, rating and overview are on screen before `/movie/{id}`
/// is asked, and the rest appears when it answers.
@MainActor
final class MovieDetailsPresenter {
    weak var view: (any MovieDetailsView)?

    private enum Details {
        case idle
        case loading(Task<Void, Never>)
        case loaded(MovieDetails)
        case failed(AppError)
    }

    private let movie: Movie
    private let fetchDetails: any FetchMovieDetailsUseCase
    private let fetchWatchlistIDs: any FetchWatchlistIDsUseCase
    private let addToWatchlist: any AddToWatchlistUseCase
    private let removeFromWatchlist: any RemoveFromWatchlistUseCase
    private let imageURLBuilder: any MovieImageURLBuilder

    private var details: Details = .idle
    private var isSaved = false

    init(
        movie: Movie,
        fetchDetails: any FetchMovieDetailsUseCase,
        fetchWatchlistIDs: any FetchWatchlistIDsUseCase,
        addToWatchlist: any AddToWatchlistUseCase,
        removeFromWatchlist: any RemoveFromWatchlistUseCase,
        imageURLBuilder: any MovieImageURLBuilder
    ) {
        self.movie = movie
        self.fetchDetails = fetchDetails
        self.fetchWatchlistIDs = fetchWatchlistIDs
        self.addToWatchlist = addToWatchlist
        self.removeFromWatchlist = removeFromWatchlist
        self.imageURLBuilder = imageURLBuilder
    }

    deinit {
        if case .loading(let task) = details {
            task.cancel()
        }
    }

    var title: String { movie.title }

    // MARK: - Lifecycle

    func viewDidLoad() {
        view?.setSaved(isSaved)
        render()
        load()
        loadWatchlistState()
    }

    // MARK: - Input

    func didTapRetry() {
        load()
    }

    /// The seeded `Movie` is what gets saved, so this works before
    /// `/movie/{id}` answers — and offline, where it may never answer.
    func didTapBookmark() {
        let wasSaved = isSaved
        setSaved(!wasSaved)

        Task { [weak self] in
            guard let self else { return }

            do {
                if wasSaved {
                    try await removeFromWatchlist(id: movie.id)
                } else {
                    try await addToWatchlist(movie)
                }
            } catch let error as AppError {
                setSaved(wasSaved)
                view?.showToast(error.message)
            } catch {
                setSaved(wasSaved)
                view?.showToast(AppError.unknown.message)
            }
        }
    }

    // MARK: - Watchlist

    private func loadWatchlistState() {
        Task { [weak self] in
            guard let self, let saved = try? await fetchWatchlistIDs() else { return }
            setSaved(saved.contains(movie.id))
        }
    }

    private func setSaved(_ isSaved: Bool) {
        self.isSaved = isSaved
        view?.setSaved(isSaved)
    }

    // MARK: - Loading

    private func load() {
        if case .loading(let task) = details {
            task.cancel()
        }

        details = .loading(
            Task { [weak self] in
                guard let self else { return }

                let outcome: Result<MovieDetails, AppError>
                do {
                    outcome = .success(try await fetchDetails(id: movie.id))
                } catch let error as AppError {
                    outcome = .failure(error)
                } catch {
                    outcome = .failure(.unknown)
                }

                guard !Task.isCancelled else { return }

                switch outcome {
                case .success(let loaded): details = .loaded(loaded)
                case .failure(let error): details = .failed(error)
                }
                render()
            }
        )
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
