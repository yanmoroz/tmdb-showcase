import Foundation

/// Drops a film from the saved list. Removing one that is not there succeeds:
/// the caller wanted it gone, and it is.
public protocol RemoveFromWatchlistUseCase: Sendable {
    func callAsFunction(id: Movie.ID) async throws(AppError)
}

public struct RemoveFromWatchlist: RemoveFromWatchlistUseCase {
    private let repository: any WatchlistRepository

    public init(repository: any WatchlistRepository) {
        self.repository = repository
    }

    public func callAsFunction(id: Movie.ID) async throws(AppError) {
        try await repository.remove(id: id)
    }
}
