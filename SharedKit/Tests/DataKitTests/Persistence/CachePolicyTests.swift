import Testing
import Foundation
import DomainKit
@testable import DataKit

/// `isFresh` is pure in its arguments, so the whole rule is exercised here with
/// no repository, no store and no clock.
@Suite("CacheWindow")
struct CacheWindowTests {
    private static let written = Date(timeIntervalSince1970: 1_700_000_000)
    private static let window = CacheWindow(duration: 3600)

    @Test("A copy younger than the window is fresh")
    func acceptsYoungCopy() {
        #expect(Self.window.isFresh(Self.written, at: Self.written.addingTimeInterval(3599)))
    }

    @Test("A copy exactly at the window is stale")
    func rejectsCopyAtTheBoundary() {
        // Pins < against <=, which flips silently in a refactor.
        #expect(!Self.window.isFresh(Self.written, at: Self.written.addingTimeInterval(3600)))
    }

    @Test("A copy older than the window is stale")
    func rejectsOldCopy() {
        #expect(!Self.window.isFresh(Self.written, at: Self.written.addingTimeInterval(7200)))
    }

    /// The stamp is wall-clock and survives relaunch, so a device clock moved
    /// backwards would otherwise hold a row fresh for the whole skew.
    @Test("A copy stamped in the future is stale")
    func rejectsFutureStamp() {
        #expect(!Self.window.isFresh(Self.written, at: Self.written.addingTimeInterval(-1)))
    }

    @Test("The clock is read afresh each time")
    func readsTheClockEachTime() {
        nonisolated(unsafe) var reads = 0
        let window = CacheWindow(duration: 3600, clock: {
            reads += 1
            return Self.written
        })

        _ = window.now
        _ = window.now

        #expect(reads == 2)
    }
}

@Suite("AppError.allowsCacheFallback")
struct CachePolicyTests {
    @Test("Only transport failures allow a cached answer", arguments: [
        AppError.network(.offline),
        .network(.timedOut),
        .network(.cannotConnect),
        .network(.other),
    ])
    func transportFailuresAllowFallback(error: AppError) {
        #expect(error.allowsCacheFallback)
    }

    @Test("Every other failure reaches the caller", arguments: [
        AppError.regionRestricted,
        .cancelled,
        .unauthorized,
        .rateLimited,
        .notFound,
        .decoding,
        .server(statusCode: 503),
        .storage,
        .unknown,
    ])
    func everythingElseIsRethrown(error: AppError) {
        #expect(!error.allowsCacheFallback)
    }
}
