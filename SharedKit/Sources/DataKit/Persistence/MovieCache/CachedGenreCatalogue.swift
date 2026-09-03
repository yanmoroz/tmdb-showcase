import Foundation
import SwiftData
import DomainKit

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
