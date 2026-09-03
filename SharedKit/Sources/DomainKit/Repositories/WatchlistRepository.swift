import Foundation

/// The films the reader has saved. Implemented in DataKit, on local storage
/// rather than TMDB — the only repository with no network behind it.
///
/// Writes are `throws(AppError)` and mean it: unlike a cache miss, which is
/// invisible by design, a save that quietly failed leaves the reader believing a
/// film is on their list when it is not.
public protocol WatchlistRepository: Sendable {
    /// The saved films themselves, newest first. Whole `Movie` values rather
    /// than identifiers, so the list renders with no network and a cold cache.
    func savedMovies() async throws(AppError) -> [Movie]

    /// Just the identifiers, for overlaying "saved" onto a feed that came from
    /// somewhere else.
    func savedIdentifiers() async throws(AppError) -> Set<Movie.ID>

    func save(_ movie: Movie) async throws(AppError)

    func remove(id: Movie.ID) async throws(AppError)
}
