import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("TMDBMoviesRepository")
struct MoviesRepositoryTests {
    private func makeRepository(_ response: StubResponse) -> (TMDBMoviesRepository, StubSession) {
        let stub = StubURLProtocol.makeSession(response)
        return (TMDBMoviesRepository(configuration: .test, session: stub.session), stub)
    }

    @Test("Страница проходит весь путь от JSON до домена")
    func loadsPage() async throws {
        let (repository, _) = makeRepository(.json(try TestFixtures.data("popular_page1")))

        let page = try await repository.movies(query: .popular, page: 1)

        #expect(page.items.count == 2)
        #expect(page.items.first?.title == "Dune: Part Two")
        #expect(page.totalPages == 500)
    }

    @Test("Запрошенный URL собирается из доменного запроса")
    func buildsRequestURL() async throws {
        let (repository, stub) = makeRepository(.json(try TestFixtures.data("popular_page1")))

        _ = try await repository.movies(query: .trending(.week), page: 3)

        let request = try #require(stub.lastRequest)
        #expect(request.url?.path() == "/3/trending/movie/week")
        #expect(request.url?.query()?.contains("page=3") == true)
    }

    @Test("Заголовок авторизации доезжает до транспорта")
    func sendsAuthorizationHeader() async throws {
        let (repository, stub) = makeRepository(.json(try TestFixtures.data("popular_page1")))

        _ = try await repository.movies(query: .popular, page: 1)

        let request = try #require(stub.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    @Test("Детали фильма запрашиваются по идентификатору")
    func loadsDetails() async throws {
        let (repository, stub) = makeRepository(.json(try TestFixtures.data("movie_details")))

        let details = try await repository.movieDetails(id: 550)

        #expect(details.title == "Fight Club")
        #expect(stub.lastRequest?.url?.path() == "/3/movie/550")
    }

    @Test("Отсутствующий фильм отдаёт notFound")
    func mapsNotFound() async {
        let (repository, _) = makeRepository(.status(404))

        await #expect(throws: AppError.notFound) {
            try await repository.movieDetails(id: 1)
        }
    }

    @Test("Гео-блокировка отдаёт regionRestricted")
    func mapsRegionRestricted() async {
        let (repository, _) = makeRepository(.status(403))

        await #expect(throws: AppError.regionRestricted) {
            try await repository.movies(query: .popular, page: 1)
        }
    }

    @Test("Обрыв связи отдаёт network(.offline)")
    func mapsTransportFailure() async {
        let (repository, _) = makeRepository(.transport(.notConnectedToInternet))

        await #expect(throws: AppError.network(.offline)) {
            try await repository.movies(query: .popular, page: 1)
        }
    }

    @Test("Битый JSON отдаёт decoding, а не unknown")
    func mapsDecodingFailure() async {
        let (repository, _) = makeRepository(.json(Data(#"{"unexpected": true}"#.utf8)))

        await #expect(throws: AppError.decoding) {
            try await repository.movies(query: .popular, page: 1)
        }
    }
}

@Suite("TMDBGenresRepository")
struct GenresRepositoryTests {
    @Test("Справочник жанров проходит путь до домена")
    func loadsGenres() async throws {
        let stub = StubURLProtocol.makeSession(.json(try TestFixtures.data("genres")))
        let repository = TMDBGenresRepository(configuration: .test, session: stub.session)

        let genres = try await repository.genres()

        #expect(genres == Genre.fixtures)
        #expect(stub.lastRequest?.url?.path() == "/3/genre/movie/list")
    }
}

@Suite("TMDBImageURLBuilder")
struct ImageURLBuilderTests {
    private let builder = TMDBImageURLBuilder(configuration: .test)

    @Test("Относительный путь превращается в URL нужного размера")
    func buildsPosterURL() {
        #expect(
            builder.posterURL(path: "/poster1.jpg", size: .w342)
                == URL(string: "https://image.tmdb.org/t/p/w342/poster1.jpg")
        )
    }

    @Test("Backdrop собирается своим набором размеров")
    func buildsBackdropURL() {
        #expect(
            builder.backdropURL(path: "/backdrop1.jpg", size: .original)
                == URL(string: "https://image.tmdb.org/t/p/original/backdrop1.jpg")
        )
    }

    @Test("Отсутствующий путь не даёт URL", arguments: [nil, ""])
    func returnsNilWithoutPath(path: String?) {
        #expect(builder.posterURL(path: path) == nil)
        #expect(builder.backdropURL(path: path) == nil)
    }
}
