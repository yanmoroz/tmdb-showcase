import Foundation

/// The saved identifiers, which presentation overlays onto whatever films it is
/// already showing.
public protocol FetchWatchlistIDsUseCase: Sendable {
    func callAsFunction() async throws(AppError) -> Set<Movie.ID>
}

public struct FetchWatchlistIDs: FetchWatchlistIDsUseCase {
    private let repository: any WatchlistRepository

    public init(repository: any WatchlistRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws(AppError) -> Set<Movie.ID> {
        try await repository.savedIdentifiers()
    }
}
