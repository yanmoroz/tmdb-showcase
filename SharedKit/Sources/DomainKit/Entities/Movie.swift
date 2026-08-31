import Foundation

/// A movie as it appears in lists: popular, trending, search results, genre feed.
///
/// A separate type from ``MovieDetails``: list payloads carry no runtime, tagline
/// or genre objects.
public struct Movie: Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let overview: String
    /// Relative poster path (`/abc123.jpg`). The full URL depends on the size
    /// and the CDN address, so DataKit builds it.
    public let posterPath: String?
    /// Relative backdrop path — see ``posterPath``.
    public let backdropPath: String?
    public let releaseDate: Date?
    /// Average rating, 0...10.
    public let voteAverage: Double
    public let voteCount: Int
    public let genreIDs: [Genre.ID]

    public init(
        id: Int,
        title: String,
        overview: String,
        posterPath: String?,
        backdropPath: String?,
        releaseDate: Date?,
        voteAverage: Double,
        voteCount: Int,
        genreIDs: [Genre.ID]
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.releaseDate = releaseDate
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.genreIDs = genreIDs
    }
}
