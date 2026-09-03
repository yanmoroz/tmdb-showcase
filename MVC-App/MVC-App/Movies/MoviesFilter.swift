import DomainKit

/// What the user has configured, as opposed to what is currently on screen.
///
/// Kept apart from `MoviesQuery` so a filter survives a search: the domain
/// forbids combining the two, but the choice itself should not be forgotten
/// just because someone typed in the search field.
struct MoviesFilter: Equatable {
    /// Which feed is being browsed. A value here rather than a separate input on
    /// the controller: the screen derives its query from the search text and this
    /// one filter, and a third input would need precedence rules between them.
    enum Source: Equatable, CaseIterable {
        case catalogue
        case trending

        var title: String {
            switch self {
            case .catalogue: "Popular"
            case .trending: "Trending"
            }
        }
    }

    var source: Source = .catalogue
    var genreID: Genre.ID?
    var sort: MovieSortOption = .popularityDescending

    /// Genre and sort only mean something to `/discover`; `/trending` takes
    /// neither, which is why the sheet that sets them is unreachable under it.
    var allowsRefinement: Bool {
        source == .catalogue
    }

    private var isRefined: Bool {
        genreID != nil || sort != .popularityDescending
    }

    var query: MoviesQuery {
        switch source {
        // The week window rather than the day: a feed that turns over daily is
        // noisier than it is useful here, and `.day` stays domain surface.
        case .trending:
            .trending(.week)
        // No genre and the default order is just "popular" — no reason to spend
        // a discover request on the same thing.
        case .catalogue:
            isRefined ? .discover(genreID: genreID, sortedBy: sort) : .popular
        }
    }
}
