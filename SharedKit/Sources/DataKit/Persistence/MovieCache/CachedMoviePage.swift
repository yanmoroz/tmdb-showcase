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
