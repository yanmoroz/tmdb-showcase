import Foundation
import DomainKit

struct GenreDTO: Decodable, Sendable {
    let id: Int
    let name: String
}

extension GenreDTO {
    func toDomain() -> Genre {
        Genre(id: id, name: name)
    }
}

/// `/genre/movie/list` wraps its array in an object.
struct GenreListDTO: Decodable, Sendable {
    let genres: [GenreDTO]
}
