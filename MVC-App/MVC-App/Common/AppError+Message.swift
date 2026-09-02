import DomainKit

extension AppError {
    var message: String {
        switch self {
        case .regionRestricted:
            "TMDB is not available in your region. Turn on a VPN and try again."
        case .unauthorized:
            "TMDB rejected the access key. Check Config.xcconfig."
        case .notFound:
            "Movie not found."
        case .rateLimited:
            "Too many requests. Try again in a minute."
        case .server:
            "TMDB is temporarily unavailable."
        case .network(.offline):
            "No internet connection."
        case .network(.timedOut):
            "The server did not respond in time."
        case .network(.cannotConnect), .network(.other):
            "Could not reach the server."
        case .decoding:
            "The server returned an unexpected response."
        case .cancelled:
            "Request cancelled."
        case .unknown:
            "Something went wrong."
        }
    }
}
