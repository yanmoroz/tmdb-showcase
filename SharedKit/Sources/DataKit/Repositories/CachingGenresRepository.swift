import Foundation
import DomainKit

/// Read-through within a freshness window, then network, then stale cache.
///
/// Genres are the one resource that does not go network-first: the catalogue
/// changes on the order of years, and a fallback-only cache would still make the
/// filter screen fetch nineteen rows and show a loading row on every open.
///
/// The window governs whether the network is *skipped*, never whether old rows
/// are *usable*: once the network has failed, stale genres beat an empty filter.
/// That last fallback stays as narrow as everywhere else — `.regionRestricted`
/// must reach the user so the VPN prompt still appears, and `.cancelled` must
/// stay cancelled.
public struct CachingGenresRepository: GenresRepository {
    private let wrapped: any GenresRepository
    private let cache: GenreCacheStore
    private let window: CacheWindow

    public init(wrapping wrapped: any GenresRepository, cache: MovieCache) {
        self.init(
            wrapping: wrapped,
            cache: cache,
            window: CacheWindow(duration: CacheFreshness.genres)
        )
    }

    /// The window is a knob for tests, not for callers: how long a catalogue
    /// stays fresh is DataKit's decision, not the app's.
    init(wrapping wrapped: any GenresRepository, cache: MovieCache, window: CacheWindow) {
        self.wrapped = wrapped
        self.cache = cache.genres
        self.window = window
    }

    public func genres() async throws(AppError) -> [Genre] {
        let readAt = window.now
        let cached = await cache.genres()

        // An empty catalogue is never fresh: one blank answer from TMDB would
        // otherwise hide the real list for a week, where network-first healed on
        // the next open. That is a fact about genres, so it stays here rather
        // than in the window.
        if let cached, !cached.genres.isEmpty, window.isFresh(cached.updatedAt, at: readAt) {
            return cached.genres
        }

        do {
            let genres = try await wrapped.genres()
            await cache.save(genres, at: readAt)
            return genres
        } catch {
            guard error.allowsCacheFallback, let cached else { throw error }
            return cached.genres
        }
    }
}
