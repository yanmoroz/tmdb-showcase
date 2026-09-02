import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("CachingGenresRepository")
struct CachingGenresRepositoryTests {
    @Test("A successful answer passes through and is written to the cache")
    func writesThroughOnSuccess() async throws {
        let (sut, remote, cache) = try makeSUT()

        #expect(try await sut.genres() == Genre.fixtures)
        #expect(await cache.genres.genres() == Genre.fixtures)
        #expect(await remote.genresCalls.count == 1)
    }

    @Test("A warm cache does not spare the network")
    func staysNetworkFirst() async throws {
        let (sut, remote, _) = try makeSUT()

        _ = try await sut.genres()
        _ = try await sut.genres()

        // Network first is the recorded policy: the cache is a fallback, not a
        // read-through layer.
        #expect(await remote.genresCalls.count == 2)
    }

    @Test("A later answer replaces what was cached")
    func refreshesTheCache() async throws {
        let (sut, remote, cache) = try makeSUT()
        _ = try await sut.genres()

        let replacement = [Genre.fixture(id: 99, name: "Documentary")]
        await remote.setGenresResult(.success(replacement))
        _ = try await sut.genres()

        #expect(await cache.genres.genres() == replacement)
    }

    @Test("Going offline is answered from the cache")
    func fallsBackWhenOffline() async throws {
        let (sut, remote, _) = try makeSUT()
        _ = try await sut.genres()

        await remote.setGenresResult(.failure(.network(.offline)))

        #expect(try await sut.genres() == Genre.fixtures)
    }

    @Test("Going offline with a cold cache still fails")
    func rethrowsWhenCacheIsCold() async throws {
        let (sut, _, _) = try makeSUT(genres: .failure(.network(.timedOut)))

        await #expect(throws: AppError.network(.timedOut)) {
            try await sut.genres()
        }
    }

    /// The heart of the policy: only `.network` may be answered from disk.
    /// `.regionRestricted` in particular has to reach the user, or the VPN
    /// prompt silently turns into stale genres.
    @Test("Only a transport failure is answered from the cache", arguments: [
        AppError.regionRestricted,
        .cancelled,
        .unauthorized,
        .rateLimited,
        .notFound,
        .decoding,
        .server(statusCode: 503),
        .unknown,
    ])
    func neverMasksOtherFailures(error: AppError) async throws {
        let (sut, remote, cache) = try makeSUT()
        _ = try await sut.genres()
        #expect(await cache.genres.genres() != nil)

        await remote.setGenresResult(.failure(error))

        await #expect(throws: error) {
            try await sut.genres()
        }
    }

    // MARK: - Factory

    private func makeSUT(
        genres: Result<[Genre], AppError> = .success(Genre.fixtures)
    ) throws -> (sut: CachingGenresRepository, remote: GenresRepositoryStub, cache: MovieCache) {
        let remote = GenresRepositoryStub(genresResult: genres)
        let cache = MovieCache(container: try MovieCacheContainer.make(inMemory: true))
        return (CachingGenresRepository(wrapping: remote, cache: cache), remote, cache)
    }
}

@Suite("AppError.allowsCacheFallback")
struct CachePolicyTests {
    @Test("Only transport failures allow a cached answer", arguments: [
        AppError.network(.offline),
        .network(.timedOut),
        .network(.cannotConnect),
        .network(.other),
    ])
    func transportFailuresAllowFallback(error: AppError) {
        #expect(error.allowsCacheFallback)
    }

    @Test("Every other failure reaches the caller", arguments: [
        AppError.regionRestricted,
        .cancelled,
        .unauthorized,
        .rateLimited,
        .notFound,
        .decoding,
        .server(statusCode: 503),
        .unknown,
    ])
    func everythingElseIsRethrown(error: AppError) {
        #expect(!error.allowsCacheFallback)
    }
}
