import Foundation

/// A movie genre.
///
/// TMDB list payloads carry genre identifiers only (`Movie.genreIDs`), so names
/// are fetched separately through `GenresRepository`.
public struct Genre: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}
