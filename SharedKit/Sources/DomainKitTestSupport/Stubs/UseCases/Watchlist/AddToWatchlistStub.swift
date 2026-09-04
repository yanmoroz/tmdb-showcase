import Foundation
import DomainKit

/// The call log is a plain array of the argument rather than a `…Call` wrapper,
/// here and in ``RemoveFromWatchlistStub``: each takes one value, so
/// `#expect(await add.calls == [movie])` says everything a wrapper would.
public actor AddToWatchlistStub: AddToWatchlistUseCase {
    public private(set) var calls: [Movie] = []

    private var result: Result<Void, AppError>

    public init(result: Result<Void, AppError> = .success(())) {
        self.result = result
    }

    public func setResult(_ result: Result<Void, AppError>) {
        self.result = result
    }

    public func callAsFunction(_ movie: Movie) async throws(AppError) {
        calls.append(movie)
        try result.get()
    }
}
