import Foundation

/// Saves a film. Takes the whole `Movie` rather than its id: the store keeps a
/// snapshot so the list can be read back without a network.
public protocol AddToWatchlistUseCase: Sendable {
    func callAsFunction(_ movie: Movie) async throws(AppError)
}

public struct AddToWatchlist: AddToWatchlistUseCase {
    private let repository: any WatchlistRepository

    public init(repository: any WatchlistRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ movie: Movie) async throws(AppError) {
        try await repository.save(movie)
    }
}
