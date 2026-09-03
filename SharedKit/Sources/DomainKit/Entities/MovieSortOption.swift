/// Sort order for `/discover/movie`.
///
/// No `RawValue`: DataKit is what knows the TMDB strings (`"popularity.desc"`).
public enum MovieSortOption: Hashable, Sendable, CaseIterable {
    case popularityDescending
    case ratingDescending
    case releaseDateDescending
    case titleAscending
}
