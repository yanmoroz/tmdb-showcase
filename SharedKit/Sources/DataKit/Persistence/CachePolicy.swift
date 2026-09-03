import Foundation
import DomainKit

/// How long a stored copy may answer without asking again.
///
/// The other half of the cache policy is `AppError.allowsCacheFallback`: this
/// decides whether the network is *skipped*, that one whether a failure may be
/// *answered from disk*.
struct CacheWindow: Sendable {
    let duration: TimeInterval
    private let clock: @Sendable () -> Date

    init(duration: TimeInterval, clock: @escaping @Sendable () -> Date = { .now }) {
        self.duration = duration
        self.clock = clock
    }

    /// Read once per operation, so the freshness test and the write stamp cannot
    /// come from two different readings.
    var now: Date { clock() }

    /// Pure in its arguments: the clock is only for `now`.
    ///
    /// A stamp in the future means the device clock moved backwards — the stored
    /// date is wall-clock and survives relaunch — and refetching is cheaper than
    /// trusting it.
    func isFresh(_ updatedAt: Date, at now: Date) -> Bool {
        let age = now.timeIntervalSince(updatedAt)
        return age >= 0 && age < duration
    }
}

/// What the page and details caches keep.
///
/// They are network first, so nothing here decides what may be *served* — only
/// what is worth keeping. Serving is deliberately not age-limited: with no
/// connection, week-old films are still films, and refusing to show what is
/// already on disk would be worse than showing it slightly late.
///
/// Sweeping on write is what bounds growth. Without it every distinct search
/// string kept a page and up to twenty movie rows for the life of the install,
/// and every film whose details were opened kept a row, with nothing to remove
/// either.
enum CacheRetention {
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// A ceiling for a burst of distinct queries inside the window — a hundred
    /// searches in an afternoon should not outlive the afternoon by a week.
    static let maxPages = 50
    static let maxDetails = 200
}

enum CacheFreshness {
    /// TMDB's genre list changes on the order of years, so the filter screen
    /// need not pay for a request every time it opens.
    static let genres: TimeInterval = 7 * 24 * 60 * 60
}

extension AppError {
    /// Whether a cached answer may stand in for this failure.
    ///
    /// Deliberately not `isRetryable`, and the two sets differ: `.rateLimited`
    /// and `.server` draw a Retry button but are never served from disk. They
    /// mean TMDB is reachable and talking, so fresh data is seconds away and
    /// waiting works. `.network` means the request never left the device, where
    /// disk is the only answer that exists.
    ///
    /// Only a transport failure qualifies. `.regionRestricted` has to reach the
    /// user or the VPN prompt turns into silently stale rows, and `.cancelled`
    /// has to stay cancelled or a debounced screen answers a request the reader
    /// already abandoned.
    var allowsCacheFallback: Bool {
        if case .network = self { true } else { false }
    }
}
