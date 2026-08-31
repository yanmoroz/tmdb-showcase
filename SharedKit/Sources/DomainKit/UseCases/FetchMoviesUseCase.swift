import Foundation

/// Loads one page of the movie list.
public protocol FetchMoviesUseCase: Sendable {
    func callAsFunction(query: MoviesQuery, page: Int) async throws(AppError) -> Page<Movie>
}

public struct FetchMovies: FetchMoviesUseCase {
    private let repository: any MoviesRepository

    public init(repository: any MoviesRepository) {
        self.repository = repository
    }

    public func callAsFunction(query: MoviesQuery, page: Int) async throws(AppError) -> Page<Movie> {
        try await repository.movies(query: query, page: page)
    }
}
