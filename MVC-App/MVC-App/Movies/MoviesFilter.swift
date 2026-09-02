import DomainKit

/// What the user has configured, as opposed to what is currently on screen.
///
/// Kept apart from `MoviesQuery` so a filter survives a search: the domain
/// forbids combining the two, but the choice itself should not be forgotten
/// just because someone typed in the search field.
struct MoviesFilter: Equatable {
    var genreID: Genre.ID?
    var sort: MovieSortOption = .popularityDescending

    var isDefault: Bool {
        genreID == nil && sort == .popularityDescending
    }

    /// No genre and the default order is just "popular" — no reason to spend a
    /// discover request on the same thing.
    var query: MoviesQuery {
        isDefault ? .popular : .discover(genreID: genreID, sortedBy: sort)
    }
}
