import Foundation
import DomainKit

struct MovieDetailsDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let originalTitle: String?
    let tagline: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let genres: [GenreDTO]?
    let homepage: String?
    let videos: VideoListDTO?
}

extension MovieDetailsDTO {
    func toDomain() -> MovieDetails {
        MovieDetails(
            id: id,
            title: title,
            originalTitle: originalTitle ?? title,
            // TMDB uses "" rather than null for an absent tagline or homepage.
            tagline: tagline.nonEmpty,
            overview: overview ?? "",
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: TMDBDate.parse(releaseDate),
            runtime: runtime,
            voteAverage: voteAverage ?? 0,
            voteCount: voteCount ?? 0,
            genres: (genres ?? []).map { $0.toDomain() },
            homepage: homepage.nonEmpty.flatMap(URL.init(string:)),
            trailer: videos?.trailer
        )
    }
}
