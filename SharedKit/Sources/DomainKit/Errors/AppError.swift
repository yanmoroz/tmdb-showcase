import Foundation

/// The single domain error of the app.
///
/// Classification happens entirely at the DataKit boundary: typed `throws` keeps
/// `URLError`, `DecodingError` and the rest of the transport from leaking out.
/// No user-facing strings here — localization lives in presentation.
public enum AppError: Error, Hashable, Sendable {
    /// 403 from the CDN with no body — TMDB geo-block (RU/BY). A VPN is needed.
    case regionRestricted

    /// 401 with a structured TMDB body — the key is missing or invalid.
    case unauthorized

    /// 404 — no such movie.
    case notFound

    /// 429 — request limit exceeded.
    case rateLimited

    /// 5xx on the TMDB side.
    case server(statusCode: Int)

    /// The request never reached the server.
    case network(NetworkFailure)

    /// A response arrived but did not decode into the domain model.
    case decoding

    /// The task was cancelled — an in-flight search superseded by newer input,
    /// for example.
    ///
    /// `CancellationError` does not travel through typed `throws`, so DataKit
    /// catches cancellation and returns it here.
    case cancelled

    /// A local store could not be read or written. The only case here that
    /// never involved a network round trip.
    case storage

    case unknown

    public var isRetryable: Bool {
        switch self {
        // A full disk may clear, and a write is cheap to repeat.
        case .rateLimited, .server, .network, .storage:
            true
        case .regionRestricted, .unauthorized, .notFound, .decoding, .cancelled,
            .unknown:
            false
        }
    }
}

/// Why the request never reached the server.
public enum NetworkFailure: Hashable, Sendable {
    case offline
    case timedOut
    case cannotConnect
    case other
}
