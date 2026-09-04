import Foundation
import DomainKit

public actor RemoveFromWatchlistStub: RemoveFromWatchlistUseCase {
    public private(set) var calls: [Movie.ID] = []

    private var result: Result<Void, AppError>

    public init(result: Result<Void, AppError> = .success(())) {
        self.result = result
    }

    public func setResult(_ result: Result<Void, AppError>) {
        self.result = result
    }

    public func callAsFunction(id: Movie.ID) async throws(AppError) {
        calls.append(id)
        try result.get()
    }
}
