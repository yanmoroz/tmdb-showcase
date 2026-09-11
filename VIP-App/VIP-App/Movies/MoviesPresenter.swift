import Foundation
import DomainKit
import PresentationKit

@MainActor
protocol MoviesPresentationLogic {
    func presentFeed(_ response: MoviesModels.Response.Feed)
    func presentItem(_ response: MoviesModels.Response.Item)
    func presentOverlay(_ response: MoviesModels.Response.Overlay)

    func presentLaterPageFailure(_ response: MoviesModels.Response.Failure)
    func presentWriteFailure(_ response: MoviesModels.Response.Failure)
    func presentInputAvailability(_ response: MoviesModels.Response.InputAvailability)

    func presentRefreshEnded(_ response: MoviesModels.Response.RefreshEnded)
    func presentScrollToTop(_ response: MoviesModels.Response.ScrollToTop)
    func presentMovieSelection(_ response: MoviesModels.Response.MovieSelection)
}

/// Turns what the interactor reports into what the view draws. It stores nothing
/// but the way back to the view, which is `weak`: the view owns the interactor
/// that owns this.
@MainActor
final class MoviesPresenter: MoviesPresentationLogic {
    weak var viewController: (any MoviesDisplayLogic)?

    private let imageURLBuilder: any MovieImageURLBuilder

    init(imageURLBuilder: any MovieImageURLBuilder) {
        self.imageURLBuilder = imageURLBuilder
    }

    func presentFeed(_ response: MoviesModels.Response.Feed) {
        viewController?.displayFeed(.init(items: items(for: response)))
    }

    func presentItem(_ response: MoviesModels.Response.Item) {
        viewController?.displayItem(
            .init(index: response.index, item: model(for: response.movie, isSaved: response.isSaved))
        )
    }

    /// An overlay never covers a non-empty list: loading and empty require an
    /// empty feed here, and the interactor records a failure only when nothing
    /// has loaded.
    func presentOverlay(_ response: MoviesModels.Response.Overlay) {
        let overlay: MoviesModels.ViewModel.Overlay = switch response.activity {
        case .loading where response.isEmpty:
            .loading
        case .failed(let error):
            // Cancellation is not transient, so isRetryable leaves it out.
            // Retrying is still the only useful action left: nothing was loaded.
            .failure(message: error.message, retry: error.isRetryable || error == .cancelled)
        case .idle where response.isEmpty:
            .empty(isSearch: response.isSearching)
        default:
            .hidden
        }
        viewController?.displayOverlay(overlay)
    }

    func presentLaterPageFailure(_ response: MoviesModels.Response.Failure) {
        // The list already has content: a page error must not replace it, and a
        // cancellation is not worth reporting at all.
        guard response.error != .cancelled else { return }
        viewController?.displayToast(.init(message: response.error.message))
    }

    func presentWriteFailure(_ response: MoviesModels.Response.Failure) {
        viewController?.displayToast(.init(message: response.error.message))
    }

    /// A search overrides both, and `/trending` accepts neither genre nor sort,
    /// so under either the controls would be there to do nothing.
    func presentInputAvailability(_ response: MoviesModels.Response.InputAvailability) {
        viewController?.displayInputAvailability(
            .init(
                sourceEnabled: !response.hasSearchText,
                filterEnabled: !response.hasSearchText && response.allowsRefinement
            )
        )
    }

    func presentRefreshEnded(_ response: MoviesModels.Response.RefreshEnded) {
        viewController?.displayRefreshEnded(.init())
    }

    func presentScrollToTop(_ response: MoviesModels.Response.ScrollToTop) {
        viewController?.displayScrollToTop(.init())
    }

    func presentMovieSelection(_ response: MoviesModels.Response.MovieSelection) {
        viewController?.displayMovieSelection(.init())
    }

    // MARK: - Projection

    private func items(for response: MoviesModels.Response.Feed) -> [MovieCell.Model] {
        response.movies.map { model(for: $0, isSaved: response.savedIDs.contains($0.id)) }
    }

    private func model(for movie: Movie, isSaved: Bool) -> MovieCell.Model {
        MovieCell.Model(
            posterURL: imageURLBuilder.posterURL(path: movie.posterPath),
            title: movie.title,
            year: MovieFormatting.year(movie.releaseDate),
            rating: MovieFormatting.rating(average: movie.voteAverage, count: movie.voteCount),
            isSaved: isSaved
        )
    }
}
