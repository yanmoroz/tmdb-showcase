import DomainKit

extension MovieSortOption {
    /// The domain deliberately gives these no `RawValue` — DataKit owns the TMDB
    /// strings — so the user-facing names are written here.
    var title: String {
        switch self {
        case .popularityDescending: "Most popular"
        case .ratingDescending: "Highest rated"
        case .releaseDateDescending: "Newest first"
        case .titleAscending: "Title (A–Z)"
        }
    }
}
