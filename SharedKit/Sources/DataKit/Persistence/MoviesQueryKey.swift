import Foundation
import DomainKit

/// The persisted identity of a `MoviesQuery`.
///
/// The tokens below are the cache's own and deliberately not `tmdbValue`: those
/// are TMDB's wire format, so a rename upstream would split one logical query
/// across two keys and orphan everything written before it.
struct MoviesQueryKey: Hashable, Sendable {
    let rawValue: String

    init(_ query: MoviesQuery) {
        rawValue = switch query {
        case .popular:
            "popular"
        case .trending(let window):
            "trending.\(window.cacheToken)"
        case .search(let text):
            "search.\(text.rawValue)"
        case .discover(let genreID, let sortedBy):
            "discover.genre=\(genreID.map(String.init) ?? "any").sort=\(sortedBy.cacheToken)"
        }
    }
}

private extension TrendingWindow {
    var cacheToken: String {
        switch self {
        case .day: "day"
        case .week: "week"
        }
    }
}

private extension MovieSortOption {
    var cacheToken: String {
        switch self {
        case .popularityDescending: "popularity"
        case .ratingDescending: "rating"
        case .releaseDateDescending: "releaseDate"
        case .titleAscending: "title"
        }
    }
}
