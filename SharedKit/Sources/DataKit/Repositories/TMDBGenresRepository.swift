import Foundation
import DomainKit

public struct TMDBGenresRepository: GenresRepository {
    private let client: TMDBAPIClient

    public init(configuration: TMDBConfiguration, session: URLSession = .shared) {
        self.client = TMDBAPIClient(configuration: configuration, session: session)
    }

    public func genres() async throws(AppError) -> [Genre] {
        let response = try await client.get(
            TMDBEndpoint(path: "genre/movie/list"),
            as: GenreListDTO.self
        )
        return response.genres.map { $0.toDomain() }
    }
}
