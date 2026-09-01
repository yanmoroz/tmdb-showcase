import Foundation

/// The error envelope TMDB attaches to its own rejections.
///
/// Only its presence is load-bearing: a 403 carrying one is a real TMDB refusal,
/// a 403 without one is the CDN geo-block.
struct TMDBStatusResponse: Decodable {
    let statusCode: Int
    let statusMessage: String

    static func isPresent(in body: Data) -> Bool {
        (try? JSONDecoder.tmdb.decode(TMDBStatusResponse.self, from: body)) != nil
    }
}
