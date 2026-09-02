import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("Декодирование ответов TMDB")
struct DecodingTests {
    private func decodePage() throws -> Page<Movie> {
        let dto = try JSONDecoder.tmdb.decode(
            PagedResponseDTO<MovieDTO>.self,
            from: try TestFixtures.data("popular_page1")
        )
        return dto.toDomain { $0.toDomain() }
    }

    @Test("Список фильмов разбирается в доменные сущности")
    func decodesMovieList() throws {
        let page = try decodePage()
        let first = try #require(page.items.first)

        #expect(page.items.count == 2)
        #expect(first.id == 693134)
        #expect(first.title == "Dune: Part Two")
        #expect(first.posterPath == "/poster1.jpg")
        #expect(first.voteAverage == 8.15)
        #expect(first.genreIDs == [28, 878])
    }

    @Test("Дата релиза разбирается из yyyy-MM-dd")
    func decodesReleaseDate() throws {
        let releaseDate = try #require(try decodePage().items.first?.releaseDate)
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(secondsFromGMT: 0)!,
            from: releaseDate
        )

        #expect(components.year == 2024)
        #expect(components.month == 2)
        #expect(components.day == 27)
    }

    @Test("Пустая строка даты становится nil, а не роняет страницу")
    func emptyReleaseDateBecomesNil() throws {
        let page = try decodePage()

        #expect(page.items.last?.releaseDate == nil)
        #expect(page.items.count == 2)
    }

    @Test("Отсутствующие поля подменяются, запись не теряется")
    func toleratesMissingFields() throws {
        let sparse = try #require(try decodePage().items.last)

        #expect(sparse.id == 1119878)
        #expect(sparse.overview == "")
        #expect(sparse.voteAverage == 0)
        #expect(sparse.voteCount == 0)
        #expect(sparse.genreIDs == [])
        #expect(sparse.posterPath == nil)
    }

    @Test("totalPages зажимается до предела TMDB")
    func clampsTotalPages() throws {
        let page = try decodePage()

        // The fixture reports 45231; unclamped, hasNextPage would promise a page
        // that cannot be fetched.
        #expect(page.totalPages == 500)
        #expect(page.totalResults == 904611)
        #expect(page.page == 1)
    }

    @Test("Детали фильма разбираются целиком")
    func decodesMovieDetails() throws {
        let details = try JSONDecoder.tmdb
            .decode(MovieDetailsDTO.self, from: try TestFixtures.data("movie_details"))
            .toDomain()

        #expect(details.id == 550)
        #expect(details.title == "Fight Club")
        #expect(details.originalTitle == "Fight Club")
        #expect(details.tagline == "Mischief. Mayhem. Soap.")
        #expect(details.runtime == 139)
        #expect(details.genres == [Genre(id: 18, name: "Drama"), Genre(id: 53, name: "Thriller")])
        #expect(details.homepage == URL(string: "https://www.foxmovies.com/movies/fight-club"))
    }

    @Test("Пустые строки деталей становятся nil, а не пустыми значениями")
    func emptyDetailStringsBecomeNil() throws {
        let details = try JSONDecoder.tmdb
            .decode(MovieDetailsDTO.self, from: try TestFixtures.data("movie_details_sparse"))
            .toDomain()

        #expect(details.tagline == nil)
        #expect(details.homepage == nil)
        #expect(details.runtime == nil)
        #expect(details.releaseDate == nil)
        #expect(details.genres == [])
        // TMDB omits original_title on some records, so title stands in.
        #expect(details.originalTitle == "Sparse Movie")
    }

    @Test("Справочник жанров разбирается из обёртки")
    func decodesGenres() throws {
        let genres = try JSONDecoder.tmdb
            .decode(GenreListDTO.self, from: try TestFixtures.data("genres"))
            .genres
            .map { $0.toDomain() }

        #expect(genres == Genre.fixtures)
    }
}
