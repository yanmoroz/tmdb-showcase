import Foundation
import DomainKit

/// The three watchlist use-case stubs.
///
/// Their call logs are plain arrays of the argument rather than `…Call` wrappers:
/// each takes at most one value, so `#expect(await add.calls == [movie])` says
/// everything a wrapper would.
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
