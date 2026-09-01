import Foundation

struct TMDBEndpoint: Hashable, Sendable {
    let path: String
    var queryItems: [URLQueryItem] = []

    func urlRequest(_ configuration: TMDBConfiguration) -> URLRequest {
        var components = URLComponents(
            url: configuration.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        // Assembled from a validated base URL and URLQueryItem, which escapes on
        // its own — a nil here means a malformed literal path, not bad user input.
        guard let url = components?.url else {
            preconditionFailure("Malformed TMDB endpoint: \(path)")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
