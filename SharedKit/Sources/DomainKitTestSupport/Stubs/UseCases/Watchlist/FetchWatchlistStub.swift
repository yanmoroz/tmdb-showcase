import Foundation
import DomainKit

public actor FetchWatchlistStub: FetchWatchlistUseCase {
    public private(set) var callCount = 0

    private var result: Result<[Movie], AppError>

    public init(result: Result<[Movie], AppError> = .success([])) {
        self.result = result
    }

    public func setResult(_ result: Result<[Movie], AppError>) {
        self.result = result
    }

    public func callAsFunction() async throws(AppError) -> [Movie] {
        callCount += 1
        return try result.get()
    }
}
