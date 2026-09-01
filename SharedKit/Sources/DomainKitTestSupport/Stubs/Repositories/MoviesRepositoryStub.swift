import Foundation
import DomainKit

/// A configurable ``MoviesRepository`` stub with a call log.
///
/// An actor rather than a class: the protocol requires `Sendable` and the log is
/// mutable.
public actor MoviesRepositoryStub: MoviesRepository {
    public private(set) var moviesCalls: [MoviesCall] = []
    public private(set) var movieDetailsCalls: [MovieDetailsCall] = []

    private var moviesResult: Result<Page<Movie>, AppError>
    private var movieDetailsResult: Result<MovieDetails, AppError>

    public init(
        moviesResult: Result<Page<Movie>, AppError> = .success(.empty()),
        movieDetailsResult: Result<MovieDetails, AppError> = .success(.fixture())
    ) {
        self.moviesResult = moviesResult
        self.movieDetailsResult = movieDetailsResult
    }

    public func setMoviesResult(_ result: Result<Page<Movie>, AppError>) {
        moviesResult = result
    }

    public func setMovieDetailsResult(_ result: Result<MovieDetails, AppError>) {
        movieDetailsResult = result
    }

    public func movies(query: MoviesQuery, page: Int) async throws(AppError) -> Page<Movie> {
        moviesCalls.append(MoviesCall(query: query, page: page))
        return try moviesResult.get()
    }

    public func movieDetails(id: Movie.ID) async throws(AppError) -> MovieDetails {
        movieDetailsCalls.append(MovieDetailsCall(id: id))
        return try movieDetailsResult.get()
    }
}
