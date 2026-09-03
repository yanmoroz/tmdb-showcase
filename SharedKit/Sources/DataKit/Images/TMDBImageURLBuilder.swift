import Foundation
import DomainKit

/// Turns the relative paths the domain stores (`/abc123.jpg`) into CDN URLs.
///
/// Sizes are enums, not strings: TMDB accepts a fixed set and answers 404 for
/// anything else.
public struct TMDBImageURLBuilder: Sendable {
    public enum PosterSize: String, Sendable, CaseIterable {
        case w154, w342, w500, original
    }

    public enum BackdropSize: String, Sendable, CaseIterable {
        case w300, w780, w1280, original
    }

    private let imageBaseURL: URL

    public init(configuration: TMDBConfiguration) {
        self.imageBaseURL = configuration.imageBaseURL
    }

    public func posterURL(path: String?, size: PosterSize) -> URL? {
        url(path: path, size: size.rawValue)
    }

    public func backdropURL(path: String?, size: BackdropSize) -> URL? {
        url(path: path, size: size.rawValue)
    }

    private func url(path: String?, size: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return imageBaseURL
            .appending(path: size)
            .appending(path: path)
    }
}

/// The sizes presentation gets when it does not name one — and it never does,
/// since the domain protocol has no size parameter. One size per kind means a
/// poster the grid downloaded is the same file the details screen asks for,
/// so the image cache above answers instead of the CDN.
extension TMDBImageURLBuilder: MovieImageURLBuilder {
    public func posterURL(path: String?) -> URL? {
        posterURL(path: path, size: .w342)
    }

    public func backdropURL(path: String?) -> URL? {
        backdropURL(path: path, size: .w780)
    }
}
