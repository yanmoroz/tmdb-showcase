import Testing
import DomainKit
import DomainKitTestSupport

@Suite("FetchMovies")
struct FetchMoviesTests {
    // No validation here on purpose — it lives in presentation, see SearchTextTests.

    @Test("The query reaches the repository unchanged", arguments: [
        MoviesQuery.popular,
        MoviesQuery.trending(.day),
        MoviesQuery.trending(.week),
        MoviesQuery.search(.fixture("dune")),
        MoviesQuery.discover(genreID: 28, sortedBy: .ratingDescending),
        MoviesQuery.discover(genreID: nil, sortedBy: .popularityDescending),
    ])
    func queryPassesThrough(query: MoviesQuery) async throws {
        let repository = MoviesRepositoryStub()
        let fetchMovies = FetchMovies(repository: repository)

        _ = try await fetchMovies(query: query, page: 2)

        let calls = await repository.moviesCalls
        #expect(calls == [MoviesCall(query: query, page: 2)])
    }

    @Test("The repository page is returned as is")
    func returnsRepositoryPage() async throws {
        let expected = Page.fixture(items: Movie.fixtures(count: 20), page: 2, totalPages: 5, totalResults: 100)
        let repository = MoviesRepositoryStub(moviesResult: .success(expected))
        let fetchMovies = FetchMovies(repository: repository)

        let page = try await fetchMovies(query: .popular, page: 2)

        #expect(page == expected)
    }

    @Test("A repository error is propagated unchanged")
    func propagatesError() async {
        let repository = MoviesRepositoryStub(moviesResult: .failure(.regionRestricted))
        let fetchMovies = FetchMovies(repository: repository)

        await #expect(throws: AppError.regionRestricted) {
            try await fetchMovies(query: .popular, page: 1)
        }
    }

    @Test("The error is not substituted for search either")
    func propagatesErrorForSearch() async {
        let repository = MoviesRepositoryStub(moviesResult: .failure(.network(.offline)))
        let fetchMovies = FetchMovies(repository: repository)

        await #expect(throws: AppError.network(.offline)) {
            try await fetchMovies(query: .search(.fixture("dune")), page: 1)
        }
    }
}
