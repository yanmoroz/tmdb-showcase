import Foundation

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

    public func posterURL(path: String?, size: PosterSize = .w342) -> URL? {
        url(path: path, size: size.rawValue)
    }

    public func backdropURL(path: String?, size: BackdropSize = .w780) -> URL? {
        url(path: path, size: size.rawValue)
    }

    private func url(path: String?, size: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return imageBaseURL
            .appending(path: size)
            .appending(path: path)
    }
}
