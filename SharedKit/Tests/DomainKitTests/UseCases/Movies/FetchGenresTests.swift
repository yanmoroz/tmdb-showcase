import Testing
import DomainKit
import DomainKitTestSupport

@Suite("FetchGenres")
struct FetchGenresTests {
    @Test("Genres come from the repository in a single call")
    func returnsGenres() async throws {
        let repository = GenresRepositoryStub(genresResult: .success(Genre.fixtures))
        let fetchGenres = FetchGenres(repository: repository)

        let genres = try await fetchGenres()

        #expect(genres == Genre.fixtures)
        await #expect(repository.genresCalls.count == 1)
    }

    @Test("A catalogue error is propagated")
    func propagatesError() async {
        let repository = GenresRepositoryStub(genresResult: .failure(.unauthorized))
        let fetchGenres = FetchGenres(repository: repository)

        await #expect(throws: AppError.unauthorized) {
            try await fetchGenres()
        }
    }
}
