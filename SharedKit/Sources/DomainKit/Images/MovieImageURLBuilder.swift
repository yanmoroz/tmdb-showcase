import Foundation

/// Turns the relative artwork paths stored on `Movie` and `MovieDetails`
/// (`/abc123.jpg`) into URLs. Implemented in DataKit, which owns the CDN host
/// and picks the size.
public protocol MovieImageURLBuilder: Sendable {
    func posterURL(path: String?) -> URL?
    func backdropURL(path: String?) -> URL?
}
