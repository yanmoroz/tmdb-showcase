import Foundation
import DomainKit

/// A configurable ``WatchlistRepository`` stub with a call log.
///
/// The write logs are plain arrays of the argument rather than `…Call` wrappers,
/// as in ``AddToWatchlistStub``: each takes one value, so
/// `#expect(await repository.saveCalls == [movie])` says everything a wrapper
/// would.
public actor WatchlistRepositoryStub: WatchlistRepository {
    public private(set) var savedMoviesCallCount = 0
    public private(set) var savedIdentifiersCallCount = 0
    public private(set) var saveCalls: [Movie] = []
    public private(set) var removeCalls: [Movie.ID] = []

    private let savedMoviesResult: Result<[Movie], AppError>
    private let savedIdentifiersResult: Result<Set<Movie.ID>, AppError>
    private let saveResult: Result<Void, AppError>
    private let removeResult: Result<Void, AppError>

    public init(
        savedMoviesResult: Result<[Movie], AppError> = .success([]),
        savedIdentifiersResult: Result<Set<Movie.ID>, AppError> = .success([]),
        saveResult: Result<Void, AppError> = .success(()),
        removeResult: Result<Void, AppError> = .success(())
    ) {
        self.savedMoviesResult = savedMoviesResult
        self.savedIdentifiersResult = savedIdentifiersResult
        self.saveResult = saveResult
        self.removeResult = removeResult
    }

    public func savedMovies() async throws(AppError) -> [Movie] {
        savedMoviesCallCount += 1
        return try savedMoviesResult.get()
    }

    public func savedIdentifiers() async throws(AppError) -> Set<Movie.ID> {
        savedIdentifiersCallCount += 1
        return try savedIdentifiersResult.get()
    }

    public func save(_ movie: Movie) async throws(AppError) {
        saveCalls.append(movie)
        try saveResult.get()
    }

    public func remove(id: Movie.ID) async throws(AppError) {
        removeCalls.append(id)
        try removeResult.get()
    }
}
