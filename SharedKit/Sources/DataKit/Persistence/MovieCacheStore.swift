import Foundation
import SwiftData
import DomainKit

/// Cached feed pages.
///
/// `@Model` types are reference types and not `Sendable`, and neither is
/// `ModelContext`, so every method here takes and returns domain values.
/// Nothing persistent leaves the actor.
///
/// Reads and writes swallow their errors: a store that cannot answer is a miss,
/// never an `AppError` — a cache failure must not replace the caller's network
/// result.
@ModelActor
actor MovieCacheStore {
    func page(for key: MoviesQueryKey) -> Page<Movie>? {
        guard let stored = storedPage(for: key) else { return nil }

        return Page(
            items: stored.movies.sorted { $0.position < $1.position }.map(\.domain),
            page: stored.page,
            totalPages: stored.totalPages,
            totalResults: stored.totalResults
        )
    }

    func save(_ page: Page<Movie>, for key: MoviesQueryKey, at date: Date = .now) {
        let stored: CachedMoviePage
        if let existing = storedPage(for: key) {
            stored = existing
            for movie in existing.movies {
                modelContext.delete(movie)
            }
        } else {
            stored = CachedMoviePage(
                queryKey: key.rawValue,
                updatedAt: date,
                page: page.page,
                totalPages: page.totalPages,
                totalResults: page.totalResults
            )
            modelContext.insert(stored)
        }

        stored.updatedAt = date
        stored.page = page.page
        stored.totalPages = page.totalPages
        stored.totalResults = page.totalResults
        stored.movies = page.items.enumerated().map { CachedMovie(position: $0.offset, movie: $0.element) }

        pruneAll(at: date)
        modelContext.commitOrRollback()
    }

    // MARK: - Details

    func details(for id: Movie.ID) -> MovieDetails? {
        storedDetails(for: id)?.domain
    }

    func save(_ details: MovieDetails, at date: Date = .now) {
        if let existing = storedDetails(for: details.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(CachedMovieDetails(details, updatedAt: date))

        pruneAll(at: date)
        modelContext.commitOrRollback()
    }

    private func storedDetails(for id: Movie.ID) -> CachedMovieDetails? {
        var descriptor = FetchDescriptor<CachedMovieDetails>(
            predicate: #Predicate { $0.movieID == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Pages

    // MARK: - Retention

    /// Every write sweeps both tables rather than its own. A reader who browses
    /// lists but stops opening details would otherwise leave those rows for good,
    /// since nothing else ever writes them.
    private func pruneAll(at now: Date) {
        prune(CachedMoviePage.self, by: \.updatedAt, keepingNewest: CacheRetention.maxPages, at: now)
        prune(CachedMovieDetails.self, by: \.updatedAt, keepingNewest: CacheRetention.maxDetails, at: now)
    }

    /// Drops whatever is past the window or past the cap, newest kept.
    ///
    /// Rows are deleted one at a time rather than by predicate: `.cascade` on the
    /// relationship is what takes a page's movie rows with it, and a batch delete
    /// is not worth risking that for a table this small.
    private func prune<Row: PersistentModel>(
        _ type: Row.Type,
        by updatedAt: KeyPath<Row, Date> & Sendable,
        keepingNewest limit: Int,
        at now: Date
    ) {
        let descriptor = FetchDescriptor<Row>(sortBy: [SortDescriptor(updatedAt, order: .reverse)])
        guard let rows = try? modelContext.fetch(descriptor) else { return }

        let cutoff = now.addingTimeInterval(-CacheRetention.maxAge)
        for (position, row) in rows.enumerated() where position >= limit || row[keyPath: updatedAt] < cutoff {
            modelContext.delete(row)
        }
    }

    private func storedPage(for key: MoviesQueryKey) -> CachedMoviePage? {
        let rawValue = key.rawValue
        var descriptor = FetchDescriptor<CachedMoviePage>(
            predicate: #Predicate { $0.queryKey == rawValue }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
