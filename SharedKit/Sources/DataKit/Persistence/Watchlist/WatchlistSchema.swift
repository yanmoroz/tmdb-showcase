import Foundation
import SwiftData
import DomainKit

/// A saved film, stored whole.
///
/// A snapshot rather than an identifier: the list the reader curated has to
/// render with no network and a cold cache, and re-fetching every row to show it
/// would defeat the point of having saved anything.
@Model
final class SavedMovie {
    /// Not `id`: `PersistentModel` already carries one.
    @Attribute(.unique) var movieID: Int
    /// Newest first is the only order the list has; nothing here is user-ordered.
    var savedAt: Date
    var title: String
    var overview: String
    var posterPath: String?
    var backdropPath: String?
    var releaseDate: Date?
    var voteAverage: Double
    var voteCount: Int
    var genreIDs: [Int]

    init(_ movie: Movie, savedAt: Date) {
        self.movieID = movie.id
        self.savedAt = savedAt
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

/// Versioned from the first commit, unlike the cache's schema.
///
/// The cache can answer a shape change by deleting itself; this cannot, so the
/// scaffolding that makes a V2 mechanical is cheaper to write now than to
/// retrofit around data somebody already owns.
enum WatchlistSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] { [SavedMovie.self] }
}

enum WatchlistMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WatchlistSchemaV1.self] }

    static var stages: [MigrationStage] { [] }
}
