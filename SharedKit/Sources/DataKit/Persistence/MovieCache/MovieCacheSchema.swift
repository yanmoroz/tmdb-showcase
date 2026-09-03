import SwiftData

enum MovieCacheSchema {
    static let models: [any PersistentModel.Type] = [
        CachedMoviePage.self,
        CachedMovie.self,
        CachedGenreCatalogue.self,
        CachedGenre.self,
        CachedMovieDetails.self,
    ]
}
