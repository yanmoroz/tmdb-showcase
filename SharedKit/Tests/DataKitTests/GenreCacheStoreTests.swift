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

        #expect(await store.genres() == genres)
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

        #expect(await store.genres() == [Genre.fixture(id: 99, name: "Documentary")])
    }

    private func makeStore() throws -> GenreCacheStore {
        GenreCacheStore(modelContainer: try MovieCacheContainer.make(inMemory: true))
    }
}
