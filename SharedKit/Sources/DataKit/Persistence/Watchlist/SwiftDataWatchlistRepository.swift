import Foundation
import SwiftData
import DomainKit

/// The watchlist, on local storage.
///
/// A repository directly rather than a store behind a decorator, as the cache
/// has: there is no network for this to sit in front of.
///
/// It keeps the cache's boundary rule — `@Model` types and `ModelContext` are
/// not `Sendable`, so only domain values cross — but inverts its error rule.
/// The cache swallows failures because a store that cannot answer is a miss;
/// here a swallowed write leaves the reader believing a film is saved when it
/// is not, so every failure becomes `.storage` and reaches the caller.
@ModelActor
public actor SwiftDataWatchlistRepository: WatchlistRepository {
    /// `nil` when the store cannot be opened. The caller decides what to do
    /// about it — unlike `MovieCache`, this is not something to run without.
    public init?() {
        guard let container = try? WatchlistContainer.make() else { return nil }
        self.init(modelContainer: container)
    }

    public func savedMovies() async throws(AppError) -> [Movie] {
        let descriptor = FetchDescriptor<SavedMovie>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return try fetch(descriptor).map(\.domain)
    }

    public func savedIdentifiers() async throws(AppError) -> Set<Movie.ID> {
        Set(try fetch(FetchDescriptor<SavedMovie>()).map(\.movieID))
    }

    public func save(_ movie: Movie) async throws(AppError) {
        try save(movie, at: .now)
    }

    public func remove(id: Movie.ID) async throws(AppError) {
        // Removing what is not there succeeds: the caller wanted it gone, and
        // it is.
        if let stored = try stored(id: id) {
            modelContext.delete(stored)
        }
        try commit()
    }

    /// The clock is a knob for tests: `savedMovies()` orders by it.
    func save(_ movie: Movie, at date: Date) throws(AppError) {
        // Saving twice replaces rather than duplicates, and moves the film to
        // the top of the list.
        if let stored = try stored(id: movie.id) {
            modelContext.delete(stored)
        }
        modelContext.insert(SavedMovie(movie, savedAt: date))
        try commit()
    }

    private func stored(id: Movie.ID) throws(AppError) -> SavedMovie? {
        // `#Predicate` will not capture a property access inline.
        let movieID = id
        var descriptor = FetchDescriptor<SavedMovie>(
            predicate: #Predicate { $0.movieID == movieID }
        )
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }

    private func fetch<Row: PersistentModel>(
        _ descriptor: FetchDescriptor<Row>
    ) throws(AppError) -> [Row] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw .storage
        }
    }

    /// Deliberately not `ModelContext.commitOrRollback()`: that helper exists so
    /// a cache write can fail in silence.
    private func commit() throws(AppError) {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw .storage
        }
    }
}
