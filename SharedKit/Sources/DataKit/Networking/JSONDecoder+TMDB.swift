import Foundation

extension JSONDecoder {
    /// TMDB is snake_case throughout.
    ///
    /// No `dateDecodingStrategy`: TMDB sends `""` for unknown dates, which would
    /// fail the whole response. Dates are parsed per field — see ``TMDBDate``.
    static let tmdb: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
