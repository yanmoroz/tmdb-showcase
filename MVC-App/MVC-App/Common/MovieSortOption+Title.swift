import DomainKit

extension MovieSortOption {
    /// The domain deliberately gives these no `RawValue` — DataKit owns the TMDB
    /// strings — so the user-facing names are written here.
    var title: String {
        switch self {
        case .popularityDescending: "По популярности"
        case .ratingDescending: "По рейтингу"
        case .releaseDateDescending: "Сначала новые"
        case .titleAscending: "По названию"
        }
    }
}
