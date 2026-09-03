import Foundation
import SwiftData
import DomainKit

@Model
final class CachedMovieDetails {
    @Attribute(.unique) var movieID: Int
    var updatedAt: Date
    var title: String
    var originalTitle: String
    var tagline: String?
    var overview: String
    var posterPath: String?
    var backdropPath: String?
    var releaseDate: Date?
    var runtime: Int?
    var voteAverage: Double
    var voteCount: Int
    var genres: [CachedGenreValue]
    var homepage: URL?
    var trailer: CachedTrailerValue?

    init(_ details: MovieDetails, updatedAt: Date) {
        self.movieID = details.id
        self.updatedAt = updatedAt
        self.title = details.title
        self.originalTitle = details.originalTitle
        self.tagline = details.tagline
        self.overview = details.overview
        self.posterPath = details.posterPath
        self.backdropPath = details.backdropPath
        self.releaseDate = details.releaseDate
        self.runtime = details.runtime
        self.voteAverage = details.voteAverage
        self.voteCount = details.voteCount
        self.genres = details.genres.map(CachedGenreValue.init)
        self.homepage = details.homepage
        self.trailer = details.trailer.map(CachedTrailerValue.init)
    }

    var domain: MovieDetails {
        MovieDetails(
            id: movieID,
            title: title,
            originalTitle: originalTitle,
            tagline: tagline,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            runtime: runtime,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genres: genres.map(\.domain),
            homepage: homepage,
            trailer: trailer?.domain
        )
    }
}

/// A genre as it sits inside one cached details record.
///
/// A stored value rather than a row: catalogue genres are a resource the filter
/// screen browses, while a film's genres are an attribute of that film with no
/// identity of their own. A Codable array also keeps its order for free.
struct CachedGenreValue: Codable, Hashable {
    var id: Int
    var name: String

    init(_ genre: Genre) {
        self.id = genre.id
        self.name = genre.name
    }

    var domain: Genre { Genre(id: id, name: name) }
}

/// Stored beside the details for the same reason genres are: a trailer has no
/// identity of its own, and an offline card without one would be worse than the
/// online card it is standing in for.
struct CachedTrailerValue: Codable, Hashable {
    var youtubeKey: String
    var name: String

    init(_ trailer: MovieTrailer) {
        self.youtubeKey = trailer.youtubeKey
        self.name = trailer.name
    }

    var domain: MovieTrailer {
        MovieTrailer(youtubeKey: youtubeKey, name: name)
    }
}
