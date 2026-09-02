import Testing
import DomainKit
import DomainKitTestSupport

@Suite("FetchMovieDetails")
struct FetchMovieDetailsTests {
    @Test("The identifier reaches the repository and details come back untouched")
    func passesIDAndReturnsDetails() async throws {
        let expected = MovieDetails.fixture(id: 42, title: "Dune", runtime: 155)
        let repository = MoviesRepositoryStub(movieDetailsResult: .success(expected))
        let fetchDetails = FetchMovieDetails(repository: repository)

        let details = try await fetchDetails(id: 42)

        #expect(details == expected)
        await #expect(repository.movieDetailsCalls == [MovieDetailsCall(id: 42)])
    }

    @Test("A missing movie yields notFound")
    func propagatesNotFound() async {
        let repository = MoviesRepositoryStub(movieDetailsResult: .failure(.notFound))
        let fetchDetails = FetchMovieDetails(repository: repository)

        await #expect(throws: AppError.notFound) {
            try await fetchDetails(id: 1)
        }
    }
}
