import Foundation

/// The saved films themselves, newest first — what the Watchlist screen lists.
///
/// Deliberately not the same read as ``FetchWatchlistIDsUseCase``: that one
/// answers "is this one saved" about a feed that came from somewhere else, and
/// pays for neither the ordering nor a whole `Movie` per row.
public protocol FetchWatchlistUseCase: Sendable {
    func callAsFunction() async throws(AppError) -> [Movie]
}

public struct FetchWatchlist: FetchWatchlistUseCase {
    private let repository: any WatchlistRepository

    public init(repository: any WatchlistRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws(AppError) -> [Movie] {
        try await repository.savedMovies()
    }
}
