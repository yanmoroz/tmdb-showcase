import Foundation
import SwiftData

/// The Movies feature's cache: one container, one store per resource.
public struct MovieCache: Sendable {
    let movies: MovieCacheStore
    let genres: GenreCacheStore

    /// `nil` when the store cannot be opened — the app then runs without a
    /// cache rather than not at all.
    public init?() {
        guard let container = try? MovieCacheContainer.make() else { return nil }
        self.init(container: container)
    }

    init(container: ModelContainer) {
        self.movies = MovieCacheStore(modelContainer: container)
        self.genres = GenreCacheStore(modelContainer: container)
    }
}
