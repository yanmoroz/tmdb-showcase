import Foundation
import DomainKit

/// The one place in the package that talks to the network, and the one place
/// where an ``AppError`` is born.
struct TMDBAPIClient: Sendable {
    private let configuration: TMDBConfiguration
    private let session: URLSession

    init(configuration: TMDBConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func get<Response: Decodable>(
        _ endpoint: TMDBEndpoint,
        as responseType: Response.Type
    ) async throws(AppError) -> Response {
        do {
            let (data, response) = try await session.data(for: endpoint.urlRequest(configuration))

            guard let http = response as? HTTPURLResponse else {
                throw AppError.unknown
            }
            guard (200..<300).contains(http.statusCode) else {
                throw AppError(httpStatusCode: http.statusCode, body: data)
            }

            do {
                return try JSONDecoder.tmdb.decode(responseType, from: data)
            } catch {
                throw AppError.decoding
            }
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError(transportError: error)
        }
    }
}
