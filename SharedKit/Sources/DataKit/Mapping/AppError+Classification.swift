import Foundation
import DomainKit

extension AppError {
    /// Classifies an HTTP rejection.
    ///
    /// Order matters: 404 and 429 are matched before the 5xx range, so
    /// `.server` never overlaps the errors that have their own case.
    init(httpStatusCode: Int, body: Data) {
        switch httpStatusCode {
        case 401:
            self = .unauthorized
        case 403:
            // The CDN geo-block answers 403 with an empty body; a genuine TMDB 403
            // carries its status envelope. Collapsing both into .regionRestricted
            // would advise a VPN to someone whose token is simply wrong.
            self = TMDBStatusResponse.isPresent(in: body) ? .unauthorized : .regionRestricted
        case 404:
            self = .notFound
        case 429:
            self = .rateLimited
        case 500...599:
            self = .server(statusCode: httpStatusCode)
        default:
            self = .unknown
        }
    }

    /// Classifies a failure that never produced a response.
    init(transportError: any Error) {
        if transportError is CancellationError {
            self = .cancelled
            return
        }
        guard let urlError = transportError as? URLError else {
            self = .unknown
            return
        }
        switch urlError.code {
        case .cancelled:
            self = .cancelled
        case .notConnectedToInternet, .dataNotAllowed:
            self = .network(.offline)
        case .timedOut:
            self = .network(.timedOut)
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
            self = .network(.cannotConnect)
        default:
            self = .network(.other)
        }
    }
}
