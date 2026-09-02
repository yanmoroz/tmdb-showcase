import Foundation
import SwiftData
import DomainKit

/// The cached genre catalogue.
///
/// Its own store rather than a corner of ``MovieCacheStore``: the domain has two
/// repositories, and nineteen rows that change once a year want nothing like the
/// eviction a growing page cache will need.
@ModelActor
actor GenreCacheStore {
    func genres() -> [Genre]? {
        guard let stored = storedCatalogue() else { return nil }
        return stored.genres.sorted { $0.position < $1.position }.map(\.domain)
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
