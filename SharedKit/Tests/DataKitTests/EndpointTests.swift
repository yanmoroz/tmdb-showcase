import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("TMDBEndpoint")
struct EndpointTests {
    private func url(_ query: MoviesQuery, page: Int = 1) -> URL {
        query.endpoint(page: page).urlRequest(.test).url!
    }

    private func queryItems(_ query: MoviesQuery, page: Int = 1) -> [String: String] {
        let components = URLComponents(url: url(query, page: page), resolvingAgainstBaseURL: false)
        return Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
    }

    @Test("Каждый кейс запроса идёт по своему пути TMDB", arguments: [
        (MoviesQuery.popular, "/3/movie/popular"),
        (MoviesQuery.trending(.day), "/3/trending/movie/day"),
        (MoviesQuery.trending(.week), "/3/trending/movie/week"),
        (MoviesQuery.search(.fixture("dune")), "/3/search/movie"),
        (MoviesQuery.discover(genreID: nil, sortedBy: .popularityDescending), "/3/discover/movie"),
    ])
    func mapsQueryToPath(query: MoviesQuery, expectedPath: String) {
        #expect(url(query).path() == expectedPath)
    }

    @Test("Токен уходит Bearer-заголовком, а не параметром запроса")
    func sendsBearerToken() {
        let request = MoviesQuery.popular.endpoint(page: 1).urlRequest(.test)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.url?.query()?.contains("api_key") != true)
    }

    @Test("Поисковый текст уходит параметром query")
    func sendsSearchText() {
        #expect(queryItems(.search(.fixture("blade runner")))["query"] == "blade runner")
    }

    @Test("Поиск не подмешивает with_genres и sort_by")
    func searchCarriesNoDiscoverParameters() {
        let items = queryItems(.search(.fixture("dune")))

        #expect(items["with_genres"] == nil)
        #expect(items["sort_by"] == nil)
    }

    @Test("Сортировки маппятся в строки TMDB", arguments: [
        (MovieSortOption.popularityDescending, "popularity.desc"),
        (MovieSortOption.ratingDescending, "vote_average.desc"),
        (MovieSortOption.releaseDateDescending, "primary_release_date.desc"),
        (MovieSortOption.titleAscending, "title.asc"),
    ])
    func mapsSortOptions(option: MovieSortOption, expected: String) {
        #expect(queryItems(.discover(genreID: nil, sortedBy: option))["sort_by"] == expected)
    }

    @Test("Фильтр по жанру уходит в with_genres, а без жанра параметра нет")
    func sendsGenreFilterOnlyWhenSet() {
        #expect(queryItems(.discover(genreID: 28, sortedBy: .popularityDescending))["with_genres"] == "28")
        #expect(queryItems(.discover(genreID: nil, sortedBy: .popularityDescending))["with_genres"] == nil)
    }

    @Test("Сортировка по рейтингу добавляет порог голосов")
    func ratingSortAddsVoteFloor() {
        #expect(queryItems(.discover(genreID: nil, sortedBy: .ratingDescending))["vote_count.gte"] == "200")
        #expect(queryItems(.discover(genreID: nil, sortedBy: .titleAscending))["vote_count.gte"] == nil)
    }

    @Test("Номер страницы зажимается в 1...500", arguments: [
        (900, "500"),
        (501, "500"),
        (500, "500"),
        (1, "1"),
        (0, "1"),
        (-3, "1"),
    ])
    func clampsPage(requested: Int, expected: String) {
        #expect(queryItems(.popular, page: requested)["page"] == expected)
    }
}
