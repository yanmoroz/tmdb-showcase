import Foundation

/// A trailer that can actually be played.
///
/// TMDB lists videos across several sites; only YouTube ones are modelled,
/// because only those are playable here. Which of a film's videos counts as
/// *the* trailer is DataKit's decision, alongside the rest of TMDB's vocabulary.
public struct MovieTrailer: Identifiable, Hashable, Sendable {
    /// The YouTube video identifier — not a URL: the player takes the id, and
    /// building a watch URL is presentation's business.
    public let youtubeKey: String
    public let name: String

    public var id: String { youtubeKey }

    public init(youtubeKey: String, name: String) {
        self.youtubeKey = youtubeKey
        self.name = name
    }
}
