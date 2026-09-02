import Foundation
import SwiftData
import DomainKit

/// A page of a feed, addressed by ``MoviesQueryKey``.
///
/// `@Attribute(.unique)` rather than `#Unique`: compound uniqueness is iOS 18+,
/// and the package floor is iOS 17.
@Model
final class CachedMoviePage {
    @Attribute(.unique) var queryKey: String
    var updatedAt: Date
    var page: Int
    var totalPages: Int
    var totalResults: Int

    @Relationship(deleteRule: .cascade, inverse: \CachedMovie.feedPage)
    var movies: [CachedMovie]

    init(queryKey: String, updatedAt: Date, page: Int, totalPages: Int, totalResults: Int) {
        self.queryKey = queryKey
        self.updatedAt = updatedAt
        self.page = page
        self.totalPages = totalPages
        self.totalResults = totalResults
        self.movies = []
    }
}

/// A movie inside one cached page.
///
/// Pages own their rows outright instead of sharing one movie table: a film can
/// sit in several feeds, and duplication is cheaper than a many-to-many for a
/// store that is thrown away rather than migrated.
@Model
final class CachedMovie {
    /// SwiftData does not promise relationship array order, so it is stored.
    var position: Int
    /// Not `id`: `PersistentModel` already carries one.
    var movieID: Int
    var title: String
    var overview: String
    var posterPath: String?
    var backdropPath: String?
    var releaseDate: Date?
    var voteAverage: Double
    var voteCount: Int
    var genreIDs: [Int]

    var feedPage: CachedMoviePage?

    init(position: Int, movie: Movie) {
        self.position = position
        self.movieID = movie.id
        self.title = movie.title
        self.overview = movie.overview
        self.posterPath = movie.posterPath
        self.backdropPath = movie.backdropPath
        self.releaseDate = movie.releaseDate
        self.voteAverage = movie.voteAverage
        self.voteCount = movie.voteCount
        self.genreIDs = movie.genreIDs
    }

    var domain: Movie {
        Movie(
            id: movieID,
            title: title,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIDs: genreIDs
        )
    }
}

/// The genre catalogue, as a single row.
///
/// A row per genre could not tell "never fetched" from "fetched and empty", and
/// would have nowhere to hang the catalogue's own `updatedAt`.
@Model
final class CachedGenreCatalogue {
    @Attribute(.unique) var singletonKey: String
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CachedGenre.catalogue)
    var genres: [CachedGenre]

    init(updatedAt: Date) {
        self.singletonKey = Self.key
        self.updatedAt = updatedAt
        self.genres = []
    }

    static let key = "genres"
}

@Model
final class CachedGenre {
    var position: Int
    var genreID: Int
    var name: String

    var catalogue: CachedGenreCatalogue?

    init(position: Int, genre: Genre) {
        self.position = position
        self.genreID = genre.id
        self.name = genre.name
    }

    var domain: Genre {
        Genre(id: genreID, name: name)
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
            homepage: homepage
        )
    }
}

enum MovieCacheSchema {
    static let models: [any PersistentModel.Type] = [
        CachedMoviePage.self,
        CachedMovie.self,
        CachedGenreCatalogue.self,
        CachedGenre.self,
        CachedMovieDetails.self,
    ]
}
