import Testing
import Foundation
import SwiftData
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("GenreCacheStore")
struct GenreCacheStoreTests {
    @Test("The genre catalogue survives the round trip in order")
    func roundTripsGenres() async throws {
        let store = try makeStore()
        let genres = Array(Genre.fixtures.reversed())

        await store.save(genres)

        #expect(await store.genres()?.genres == genres)
    }

    @Test("An absent catalogue is a miss")
    func missesAbsentCatalogue() async throws {
        let store = try makeStore()

        #expect(await store.genres() == nil)
    }

    @Test("Saving the catalogue again replaces it")
    func overwritesGenres() async throws {
        let store = try makeStore()

        await store.save(Genre.fixtures)
        await store.save([Genre.fixture(id: 99, name: "Documentary")])

        #expect(await store.genres()?.genres == [Genre.fixture(id: 99, name: "Documentary")])
    }

    /// The timestamp is what the freshness window reads, so it has to survive
    /// the round trip as faithfully as the rows do.
    @Test("The catalogue remembers when it was written")
    func roundTripsTimestamp() async throws {
        let store = try makeStore()
        let written = Date(timeIntervalSince1970: 1_700_000_000)

        await store.save(Genre.fixtures, at: written)

        #expect(await store.genres()?.updatedAt == written)
    }

    @Test("Saving again moves the timestamp forward")
    func refreshesTimestamp() async throws {
        let store = try makeStore()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = first.addingTimeInterval(3600)

        await store.save(Genre.fixtures, at: first)
        await store.save(Genre.fixtures, at: second)

        #expect(await store.genres()?.updatedAt == second)
    }

    private func makeStore() throws -> GenreCacheStore {
        GenreCacheStore(modelContainer: try MovieCacheContainer.make(inMemory: true))
    }
}
