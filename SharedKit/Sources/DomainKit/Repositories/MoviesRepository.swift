import Foundation

/// The source of movies. Implemented in DataKit.
///
/// `throws(AppError)` obliges the implementation to classify every transport
/// error, cancellation included (`CancellationError` → `AppError.cancelled`).
public protocol MoviesRepository: Sendable {
    /// A single page of the feed. 1-based numbering.
    func movies(query: MoviesQuery, page: Int) async throws(AppError) -> Page<Movie>

    func movieDetails(id: Movie.ID) async throws(AppError) -> MovieDetails
}
