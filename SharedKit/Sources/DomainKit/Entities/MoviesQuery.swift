import Foundation

/// What the Movies screen shows.
///
/// `Hashable` is load-bearing: queries are compared to discard a stale load.
public enum MoviesQuery: Hashable, Sendable {
    /// `/movie/popular`
    case popular

    /// `/trending/movie/{day|week}`
    case trending(TrendingWindow)

    /// `/search/movie`. The text is already validated — see ``SearchText``.
    ///
    /// The endpoint accepts neither `with_genres` nor `sort_by`, so search cannot
    /// be combined with a genre filter: the enum makes that combination
    /// unrepresentable, and presentation dims the filter chip.
    case search(SearchText)

    /// `/discover/movie` — genre filter and sorting.
    case discover(genreID: Genre.ID?, sortedBy: MovieSortOption)
}

/// The TMDB trending window.
public enum TrendingWindow: Hashable, Sendable, CaseIterable {
    case day
    case week
}
