import Foundation

/// The full movie card for the details screen.
public struct MovieDetails: Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let originalTitle: String
    public let tagline: String?
    public let overview: String
    /// See `Movie.posterPath`.
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: Date?
    /// Runtime in minutes. `nil` — TMDB has no duration for this movie.
    public let runtime: Int?
    public let voteAverage: Double
    public let voteCount: Int
    /// Details carry genre objects rather than identifiers.
    public let genres: [Genre]
    public let homepage: URL?

    public init(
        id: Int,
        title: String,
        originalTitle: String,
        tagline: String?,
        overview: String,
        posterPath: String?,
        backdropPath: String?,
        releaseDate: Date?,
        runtime: Int?,
        voteAverage: Double,
        voteCount: Int,
        genres: [Genre],
        homepage: URL?
    ) {
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.tagline = tagline
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.releaseDate = releaseDate
        self.runtime = runtime
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.genres = genres
        self.homepage = homepage
    }
}
