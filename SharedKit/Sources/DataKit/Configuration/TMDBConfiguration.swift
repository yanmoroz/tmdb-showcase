import Foundation

/// Everything DataKit needs to reach TMDB.
///
/// Supplied by the app rather than read from `Bundle.main`: the package is
/// consumed by six -App targets and by `swift test`, where no host bundle exists.
public struct TMDBConfiguration: Sendable {
    public static let defaultBaseURL = URL(string: "https://api.themoviedb.org/3")!
    public static let defaultImageBaseURL = URL(string: "https://image.tmdb.org/t/p")!

    /// TMDB v4 access token, sent as `Authorization: Bearer`. Not the v3 `api_key`.
    public let accessToken: String
    public let baseURL: URL
    public let imageBaseURL: URL

    public init(
        accessToken: String,
        baseURL: URL = Self.defaultBaseURL,
        imageBaseURL: URL = Self.defaultImageBaseURL
    ) {
        self.accessToken = accessToken
        self.baseURL = baseURL
        self.imageBaseURL = imageBaseURL
    }
}
