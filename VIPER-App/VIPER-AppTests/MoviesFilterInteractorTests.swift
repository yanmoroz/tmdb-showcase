import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import VIPER_App

@MainActor
@Suite("MoviesFilterInteractor")
final class MoviesFilterInteractorTests {
    private weak var trackedSUT: MoviesFilterInteractor?
    private var trackedLocation: SourceLocation?

    private let output = MoviesFilterInteractorOutputSpy()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The interactor outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    @Test("The catalogue is reported")
    func reportsTheCatalogue() async throws {
        let (sut, _) = makeSUT(result: .success(Genre.fixtures))

        sut.loadGenres()

        try await waitUntil { self.output.events == [.loaded(Genre.fixtures)] }
    }

    @Test("A failure is reported as the domain error")
    func reportsFailure() async throws {
        let (sut, _) = makeSUT(result: .failure(.network(.offline)))

        sut.loadGenres()

        try await waitUntil { self.output.events == [.failed(.network(.offline))] }
    }

    /// The sheet shows the catalogue loading until it hears back.
    @Test("A cancelled request that was not replaced is still reported")
    func reportsUnrequestedCancellation() async throws {
        let (sut, _) = makeSUT(result: .failure(.cancelled))

        sut.loadGenres()

        try await waitUntil { self.output.events == [.failed(.cancelled)] }
    }

    @Test("Starting a load abandons the one in flight")
    func abandonsTheLoadInFlight() async throws {
        let (sut, fetchGenres) = makeSUT(result: .success(Genre.fixtures))

        sut.loadGenres()
        sut.loadGenres()

        try await waitUntil { await fetchGenres.calls.count == 2 }
        await drainPendingWork()

        #expect(output.events.count == 1)
    }

    // MARK: - Helpers

    private func makeSUT(
        result: Result<[Genre], AppError>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (MoviesFilterInteractor, FetchGenresStub) {
        let fetchGenres = FetchGenresStub(result: result)
        let sut = MoviesFilterInteractor(fetchGenres: fetchGenres)
        sut.output = output

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchGenres)
    }
}

/// Records what the interactor reported, in order.
@MainActor
final class MoviesFilterInteractorOutputSpy: MoviesFilterInteractorOutput {
    enum Event: Equatable {
        case loaded([Genre])
        case failed(AppError)
    }

    private(set) var events: [Event] = []

    func didLoadGenres(_ genres: [Genre]) {
        events.append(.loaded(genres))
    }

    func didFailToLoadGenres(with error: AppError) {
        events.append(.failed(error))
    }
}
