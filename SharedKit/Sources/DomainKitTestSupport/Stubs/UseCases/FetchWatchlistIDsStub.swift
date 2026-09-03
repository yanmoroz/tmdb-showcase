import Foundation
import DomainKit

public actor FetchWatchlistIDsStub: FetchWatchlistIDsUseCase {
    public private(set) var callCount = 0

    private var result: Result<Set<Movie.ID>, AppError>

    public init(result: Result<Set<Movie.ID>, AppError> = .success([])) {
        self.result = result
    }

    public func setResult(_ result: Result<Set<Movie.ID>, AppError>) {
        self.result = result
    }

    public func callAsFunction() async throws(AppError) -> Set<Movie.ID> {
        callCount += 1
        return try result.get()
    }
}
