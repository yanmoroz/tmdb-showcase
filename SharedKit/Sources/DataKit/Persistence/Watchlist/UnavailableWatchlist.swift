import DomainKit

/// Stands in when the store will not open, so the app still runs and the failure
/// reports itself the moment the reader tries to save something.
public struct UnavailableWatchlist: WatchlistRepository {
    public init() {}

    public func savedMovies() async throws(AppError) -> [Movie] { [] }

    public func savedIdentifiers() async throws(AppError) -> Set<Movie.ID> { [] }

    public func save(_ movie: Movie) async throws(AppError) { throw .storage }

    public func remove(id: Movie.ID) async throws(AppError) { throw .storage }
}
