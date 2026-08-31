import Foundation

/// Loads the movie card for the details screen.
public protocol FetchMovieDetailsUseCase: Sendable {
    func callAsFunction(id: Movie.ID) async throws(AppError) -> MovieDetails
}

public struct FetchMovieDetails: FetchMovieDetailsUseCase {
    private let repository: any MoviesRepository

    public init(repository: any MoviesRepository) {
        self.repository = repository
    }

    public func callAsFunction(id: Movie.ID) async throws(AppError) -> MovieDetails {
        try await repository.movieDetails(id: id)
    }
}
