import Testing
import DomainKit
import DomainKitTestSupport

@Suite("FetchGenres")
struct FetchGenresTests {
    @Test("Жанры отдаются из репозитория одним вызовом")
    func returnsGenres() async throws {
        let repository = GenresRepositoryStub(genresResult: .success(Genre.fixtures))
        let fetchGenres = FetchGenres(repository: repository)

        let genres = try await fetchGenres()

        #expect(genres == Genre.fixtures)
        await #expect(repository.genresCallCount == 1)
    }

    @Test("Ошибка справочника пробрасывается")
    func propagatesError() async {
        let repository = GenresRepositoryStub(genresResult: .failure(.unauthorized))
        let fetchGenres = FetchGenres(repository: repository)

        await #expect(throws: AppError.unauthorized) {
            try await fetchGenres()
        }
    }
}
