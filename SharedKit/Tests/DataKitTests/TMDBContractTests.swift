import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

/// Проверяет, что TMDB всё ещё отвечает так, как описывают фикстуры.
///
/// Фикстуры фиксируют вчерашний контракт: если TMDB переименует поле, выкинет
/// эндпоинт или перестанет принимать строку `sort_by`, герметичные тесты
/// останутся зелёными, а приложение сломается. Ловит это только живой запрос.
///
/// `.serialized` — пять запросов подряд не должны выглядеть всплеском и ловить 429.
@Suite("TMDBContract", .requiresTMDBAccess, .serialized, .tags(.live))
struct TMDBContractTests {
    private var movies: TMDBMoviesRepository {
        TMDBMoviesRepository(configuration: LiveTMDB.configuration)
    }

    @Test("Формат списка и обёртки пагинации не изменился")
    func popularStillDecodes() async throws {
        let page = try await movies.movies(query: .popular, page: 1)

        #expect(!page.items.isEmpty)
        #expect(page.page == 1)
        #expect(page.totalPages > 1)
        #expect(page.items.allSatisfy { !$0.title.isEmpty })
    }

    @Test("Строки sort_by всё ещё принимаются", arguments: MovieSortOption.allCases)
    func discoverAcceptsSortOption(option: MovieSortOption) async throws {
        // Протухшая строка даёт 422, который классификация схлопнет в .unknown.
        let page = try await movies.movies(
            query: .discover(genreID: nil, sortedBy: option),
            page: 1
        )

        #expect(!page.items.isEmpty)
    }

    @Test("Формат деталей не изменился")
    func detailsStillDecode() async throws {
        let details = try await movies.movieDetails(id: 550)

        #expect(details.title == "Fight Club")
        #expect(details.runtime != nil)
        #expect(!details.genres.isEmpty)
    }

    @Test("Справочник жанров на месте")
    func genresStillDecode() async throws {
        let repository = TMDBGenresRepository(configuration: LiveTMDB.configuration)

        let genres = try await repository.genres()

        #expect(genres.contains(Genre(id: 28, name: "Action")))
    }

    @Test("Поиск принимает параметр query")
    func searchStillWorks() async throws {
        let page = try await movies.movies(query: .search(.fixture("dune")), page: 1)

        #expect(!page.items.isEmpty)
    }
}
