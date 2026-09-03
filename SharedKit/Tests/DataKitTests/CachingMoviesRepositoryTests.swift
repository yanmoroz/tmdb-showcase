import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("CachingMoviesRepository")
struct CachingMoviesRepositoryTests {
    private static let firstPage = Page.fixture(items: Movie.fixtures(count: 3), page: 1, totalPages: 9)
    private static let secondPage = Page.fixture(items: Movie.fixtures(count: 3, startingAt: 50), page: 2, totalPages: 9)

    @Test("The first page passes through and is written to the cache")
    func writesThroughOnFirstPage() async throws {
        let (sut, _, cache) = try makeSUT(movies: .success(Self.firstPage))

        #expect(try await sut.movies(query: .popular, page: 1) == Self.firstPage)
        #expect(await cache.movies.page(for: MoviesQueryKey(.popular)) == Self.firstPage)
    }

    @Test("Later pages are never written")
    func doesNotCacheLaterPages() async throws {
        let (sut, _, cache) = try makeSUT(movies: .success(Self.secondPage))

        _ = try await sut.movies(query: .popular, page: 2)

        #expect(await cache.movies.page(for: MoviesQueryKey(.popular)) == nil)
    }

    @Test("A warm cache does not spare the network")
    func staysNetworkFirst() async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(Self.firstPage))

        _ = try await sut.movies(query: .popular, page: 1)
        _ = try await sut.movies(query: .popular, page: 1)

        #expect(await remote.moviesCalls.count == 2)
    }

    @Test("Going offline on the first page is answered from the cache")
    func fallsBackOnFirstPage() async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(Self.firstPage))
        _ = try await sut.movies(query: .popular, page: 1)

        await remote.setMoviesResult(.failure(.network(.offline)))

        #expect(try await sut.movies(query: .popular, page: 1) == Self.firstPage)
    }

    /// The other half of the write rule: a cached first page must not answer a
    /// request for page two, or the reader would silently re-read what they have.
    @Test("Going offline on a later page still fails")
    func doesNotFallBackOnLaterPages() async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(Self.firstPage))
        _ = try await sut.movies(query: .popular, page: 1)

        await remote.setMoviesResult(.failure(.network(.offline)))

        await #expect(throws: AppError.network(.offline)) {
            try await sut.movies(query: .popular, page: 2)
        }
    }

    @Test("Going offline with a cold cache still fails")
    func rethrowsWhenCacheIsCold() async throws {
        let (sut, _, _) = try makeSUT(movies: .failure(.network(.timedOut)))

        await #expect(throws: AppError.network(.timedOut)) {
            try await sut.movies(query: .popular, page: 1)
        }
    }

    @Test("Only a transport failure is answered from the cache", arguments: [
        AppError.regionRestricted,
        .cancelled,
        .unauthorized,
        .rateLimited,
        .notFound,
        .decoding,
        .server(statusCode: 503),
        .storage,
        .unknown,
    ])
    func neverMasksOtherFailures(error: AppError) async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(Self.firstPage))
        _ = try await sut.movies(query: .popular, page: 1)

        await remote.setMoviesResult(.failure(error))

        await #expect(throws: error) {
            try await sut.movies(query: .popular, page: 1)
        }
    }

    @Test("Each query keeps its own cached page")
    func keepsQueriesApart() async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(Self.firstPage))
        _ = try await sut.movies(query: .popular, page: 1)

        let searchResults = Page.fixture(items: Movie.fixtures(count: 1, startingAt: 77))
        await remote.setMoviesResult(.success(searchResults))
        _ = try await sut.movies(query: .search(.fixture("dune")), page: 1)

        await remote.setMoviesResult(.failure(.network(.offline)))

        #expect(try await sut.movies(query: .popular, page: 1) == Self.firstPage)
        #expect(try await sut.movies(query: .search(.fixture("dune")), page: 1) == searchResults)
    }

    @Test("An empty answer is cached as an answer, not as a miss")
    func cachesEmptyResults() async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(.empty()))
        _ = try await sut.movies(query: .search(.fixture("nothingmatches")), page: 1)

        await remote.setMoviesResult(.failure(.network(.offline)))

        // Offline repeats the answer TMDB gave rather than reporting a failure.
        #expect(try await sut.movies(query: .search(.fixture("nothingmatches")), page: 1).isEmpty)
    }

    // MARK: - Details

    @Test("Details pass through and are written to the cache")
    func writesThroughOnDetails() async throws {
        let (sut, remote, cache) = try makeSUT(movies: .success(Self.firstPage))
        let details = MovieDetails.fixture(id: 42, title: "Cached Film")
        await remote.setMovieDetailsResult(.success(details))

        #expect(try await sut.movieDetails(id: 42) == details)
        #expect(await cache.movies.details(for: 42) == details)
    }

    @Test("Going offline is answered from the cached details")
    func fallsBackOnDetails() async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(Self.firstPage))
        let details = MovieDetails.fixture(id: 42, title: "Cached Film")
        await remote.setMovieDetailsResult(.success(details))
        _ = try await sut.movieDetails(id: 42)

        await remote.setMovieDetailsResult(.failure(.network(.offline)))

        #expect(try await sut.movieDetails(id: 42) == details)
    }

    @Test("Going offline with no cached details still fails")
    func rethrowsWhenDetailsAreNotCached() async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(Self.firstPage))
        await remote.setMovieDetailsResult(.failure(.network(.offline)))

        await #expect(throws: AppError.network(.offline)) {
            try await sut.movieDetails(id: 42)
        }
    }

    /// A film pulled from TMDB must not be resurrected from disk: notFound is
    /// an answer, not a transport failure.
    @Test("A deleted film is not resurrected from the cache")
    func neverMasksNotFoundDetails() async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(Self.firstPage))
        await remote.setMovieDetailsResult(.success(.fixture(id: 42)))
        _ = try await sut.movieDetails(id: 42)

        await remote.setMovieDetailsResult(.failure(.notFound))

        await #expect(throws: AppError.notFound) {
            try await sut.movieDetails(id: 42)
        }
    }

    @Test("Details are addressed by their own id")
    func keepsDetailsApart() async throws {
        let (sut, remote, _) = try makeSUT(movies: .success(Self.firstPage))
        await remote.setMovieDetailsResult(.success(.fixture(id: 1, title: "First")))
        _ = try await sut.movieDetails(id: 1)

        await remote.setMovieDetailsResult(.failure(.network(.offline)))

        await #expect(throws: AppError.network(.offline)) {
            try await sut.movieDetails(id: 2)
        }
    }

    // MARK: - Factory

    private func makeSUT(
        movies: Result<Page<Movie>, AppError>
    ) throws -> (sut: CachingMoviesRepository, remote: MoviesRepositoryStub, cache: MovieCache) {
        let remote = MoviesRepositoryStub(moviesResult: movies)
        let cache = MovieCache(container: try MovieCacheContainer.make(inMemory: true))
        return (CachingMoviesRepository(wrapping: remote, cache: cache), remote, cache)
    }
}
