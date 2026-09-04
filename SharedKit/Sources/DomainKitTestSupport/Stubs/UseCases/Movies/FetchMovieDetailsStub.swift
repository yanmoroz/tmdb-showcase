import Foundation
import DomainKit

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
