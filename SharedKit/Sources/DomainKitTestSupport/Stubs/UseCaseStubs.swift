import Foundation
import DomainKit

// Use case stubs for presentation tests: Presenter / ViewModel / Interactor /
// Reducer depend on the protocols, so no fake repository is needed.

public actor FetchMoviesStub: FetchMoviesUseCase {
    public private(set) var calls: [MoviesCall] = []

    private var result: Result<Page<Movie>, AppError>

    public init(result: Result<Page<Movie>, AppError> = .success(.empty())) {
        self.result = result
    }

    public func setResult(_ result: Result<Page<Movie>, AppError>) {
        self.result = result
    }

    public func callAsFunction(query: MoviesQuery, page: Int) async throws(AppError) -> Page<Movie> {
        calls.append(MoviesCall(query: query, page: page))
        return try result.get()
    }
}

public actor FetchMovieDetailsStub: FetchMovieDetailsUseCase {
    public private(set) var calls: [MovieDetailsCall] = []

    private var result: Result<MovieDetails, AppError>

    public init(result: Result<MovieDetails, AppError> = .success(.fixture())) {
        self.result = result
    }

    public func setResult(_ result: Result<MovieDetails, AppError>) {
        self.result = result
    }

    public func callAsFunction(id: Movie.ID) async throws(AppError) -> MovieDetails {
        calls.append(MovieDetailsCall(id: id))
        return try result.get()
    }
}

public actor FetchGenresStub: FetchGenresUseCase {
    public private(set) var calls: [GenresCall] = []

    public var callCount: Int { calls.count }

    private var result: Result<[Genre], AppError>

    public init(result: Result<[Genre], AppError> = .success(Genre.fixtures)) {
        self.result = result
    }

    public func setResult(_ result: Result<[Genre], AppError>) {
        self.result = result
    }

    public func callAsFunction() async throws(AppError) -> [Genre] {
        calls.append(GenresCall())
        return try result.get()
    }
}
