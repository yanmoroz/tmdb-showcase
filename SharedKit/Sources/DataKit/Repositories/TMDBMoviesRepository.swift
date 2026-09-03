import Foundation
import DomainKit

public struct TMDBMoviesRepository: MoviesRepository {
    private let client: TMDBAPIClient

    public init(configuration: TMDBConfiguration, session: URLSession = .shared) {
        self.client = TMDBAPIClient(configuration: configuration, session: session)
    }

    public func movies(query: MoviesQuery, page: Int) async throws(AppError) -> Page<Movie> {
        let response = try await client.get(
            query.endpoint(page: page),
            as: PagedResponseDTO<MovieDTO>.self
        )
        return response.toDomain { $0.toDomain() }
    }

    public func movieDetails(id: Movie.ID) async throws(AppError) -> MovieDetails {
        let response = try await client.get(
            TMDBEndpoint(
                path: "movie/\(id)",
                queryItems: [URLQueryItem(name: "append_to_response", value: "videos")]
            ),
            as: MovieDetailsDTO.self
        )
        return response.toDomain()
    }
}
