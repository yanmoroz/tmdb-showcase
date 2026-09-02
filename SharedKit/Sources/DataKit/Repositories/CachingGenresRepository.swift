import Foundation
import DomainKit

/// Network first, cache only as a fallback.
///
/// The fallback is deliberately narrow. `.regionRestricted` must reach the user
/// so the VPN prompt still appears, and `.cancelled` must stay cancelled — a
/// debounced screen would otherwise answer an abandoned request with stale rows.
public struct CachingGenresRepository: GenresRepository {
    private let wrapped: any GenresRepository
    private let cache: GenreCacheStore

    public init(wrapping wrapped: any GenresRepository, cache: MovieCache) {
        self.wrapped = wrapped
        self.cache = cache.genres
    }

    public func genres() async throws(AppError) -> [Genre] {
        do {
            let genres = try await wrapped.genres()
            await cache.save(genres)
            return genres
        } catch {
            guard error.allowsCacheFallback, let cached = await cache.genres() else { throw error }
            return cached
        }
    }
}
