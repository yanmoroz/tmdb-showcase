import Foundation
import DomainKit

/// Network first, cache only as a fallback, and only for the first page.
///
/// Later pages are never written: they are worth little on a cold start, and
/// keeping them would mean reconciling a partially cached feed with a paging
/// cursor that only presentation understands.
///
/// The fallback is deliberately narrow, as in ``CachingGenresRepository``:
/// `.regionRestricted` must reach the user so the VPN prompt still appears, and
/// `.cancelled` must stay cancelled.
public struct CachingMoviesRepository: MoviesRepository {
    private let wrapped: any MoviesRepository
    private let cache: MovieCacheStore

    public init(wrapping wrapped: any MoviesRepository, cache: MovieCache) {
        self.wrapped = wrapped
        self.cache = cache.movies
    }

    public func movies(query: MoviesQuery, page: Int) async throws(AppError) -> Page<Movie> {
        // The transport clamps anything below 1 up to the first page, so the
        // cache agrees: otherwise a page-0 request would write a row under this
        // key that no later request could read back.
        let isFirstPage = page <= 1

        do {
            let result = try await wrapped.movies(query: query, page: page)
            if isFirstPage {
                await cache.save(result, for: MoviesQueryKey(query))
            }
            return result
        } catch {
            guard error.allowsCacheFallback,
                  isFirstPage,
                  let cached = await cache.page(for: MoviesQueryKey(query))
            else { throw error }
            return cached
        }
    }

    public func movieDetails(id: Movie.ID) async throws(AppError) -> MovieDetails {
        do {
            let details = try await wrapped.movieDetails(id: id)
            await cache.save(details)
            return details
        } catch {
            guard error.allowsCacheFallback, let cached = await cache.details(for: id) else { throw error }
            return cached
        }
    }
}
