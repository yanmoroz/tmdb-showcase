import Foundation
import DomainKit

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
