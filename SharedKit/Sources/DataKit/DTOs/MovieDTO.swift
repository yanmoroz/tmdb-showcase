import Foundation
import DomainKit

/// Everything past `id` and `title` is optional on purpose: TMDB intermittently
/// omits `overview` or `voteAverage`, and failing a whole page over one thin
/// record is the worse trade.
struct MovieDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double?
    let voteCount: Int?
    let genreIds: [Int]?
}

extension MovieDTO {
    func toDomain() -> Movie {
        Movie(
            id: id,
            title: title,
            overview: overview ?? "",
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: TMDBDate.parse(releaseDate),
            voteAverage: voteAverage ?? 0,
            voteCount: voteCount ?? 0,
            genreIDs: genreIds ?? []
        )
    }
}
