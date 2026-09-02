import Foundation
import SwiftData
import DomainKit

/// The cached genre catalogue.
///
/// Its own store rather than a corner of ``MovieCacheStore``: the domain has two
/// repositories, and nineteen rows that change once a year want nothing like the
/// eviction a growing page cache will need.
/// The stored catalogue and when it was written. The timestamp travels with
/// the rows because the freshness window is the repository's decision, not the
/// store's.
struct CachedGenres: Sendable {
    let genres: [Genre]
    let updatedAt: Date
}

@ModelActor
actor GenreCacheStore {
    func genres() -> CachedGenres? {
        guard let stored = storedCatalogue() else { return nil }

        return CachedGenres(
            genres: stored.genres.sorted { $0.position < $1.position }.map(\.domain),
            updatedAt: stored.updatedAt
        )
    }

    func save(_ genres: [Genre], at date: Date = .now) {
        let stored: CachedGenreCatalogue
        if let existing = storedCatalogue() {
            stored = existing
            for genre in existing.genres {
                modelContext.delete(genre)
            }
        } else {
            stored = CachedGenreCatalogue(updatedAt: date)
            modelContext.insert(stored)
        }

        stored.updatedAt = date
        stored.genres = genres.enumerated().map { CachedGenre(position: $0.offset, genre: $0.element) }

        modelContext.commitOrRollback()
    }

    private func storedCatalogue() -> CachedGenreCatalogue? {
        let key = CachedGenreCatalogue.key
        var descriptor = FetchDescriptor<CachedGenreCatalogue>(
            predicate: #Predicate { $0.singletonKey == key }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
