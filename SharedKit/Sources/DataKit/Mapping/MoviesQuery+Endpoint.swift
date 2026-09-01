import Foundation
import DomainKit

enum TMDBPagination {
    /// TMDB answers 400 above this page, so requests and `totalPages` are both
    /// clamped — otherwise `Page.hasNextPage` would promise an unfetchable page.
    static let maxPage = 500

    static func clamp(_ page: Int) -> Int {
        min(max(page, 1), maxPage)
    }
}

extension MoviesQuery {
    func endpoint(page: Int) -> TMDBEndpoint {
        let page = TMDBPagination.clamp(page)
        let pageItem = URLQueryItem(name: "page", value: String(page))

        switch self {
        case .popular:
            return TMDBEndpoint(path: "movie/popular", queryItems: [pageItem])

        case .trending(let window):
            return TMDBEndpoint(path: "trending/movie/\(window.tmdbPath)", queryItems: [pageItem])

        case .search(let text):
            return TMDBEndpoint(
                path: "search/movie",
                queryItems: [URLQueryItem(name: "query", value: text.rawValue), pageItem]
            )

        case .discover(let genreID, let sortedBy):
            var items = [URLQueryItem(name: "sort_by", value: sortedBy.tmdbValue), pageItem]
            if let genreID {
                items.append(URLQueryItem(name: "with_genres", value: String(genreID)))
            }
            if sortedBy == .ratingDescending {
                // Bare vote_average.desc surfaces one-vote 10.0 entries; TMDB's own
                // UI applies the same floor.
                items.append(URLQueryItem(name: "vote_count.gte", value: "200"))
            }
            return TMDBEndpoint(path: "discover/movie", queryItems: items)
        }
    }
}

extension TrendingWindow {
    var tmdbPath: String {
        switch self {
        case .day: "day"
        case .week: "week"
        }
    }
}

extension MovieSortOption {
    var tmdbValue: String {
        switch self {
        case .popularityDescending: "popularity.desc"
        case .ratingDescending: "vote_average.desc"
        case .releaseDateDescending: "primary_release_date.desc"
        case .titleAscending: "title.asc"
        }
    }
}
