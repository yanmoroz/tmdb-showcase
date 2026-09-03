import Foundation
import DomainKit

struct VideoListDTO: Decodable, Sendable {
    let results: [VideoDTO]?
}

struct VideoDTO: Decodable, Sendable {
    let key: String?
    let name: String?
    let site: String?
    let type: String?
    let official: Bool?
}

extension VideoListDTO {
    /// TMDB lists clips, featurettes and behind-the-scenes reels beside trailers,
    /// across several sites. Only a YouTube video is playable here, an official
    /// upload beats a fan one, and a trailer beats a teaser.
    var trailer: MovieTrailer? {
        (results ?? [])
            .compactMap(PlayableVideo.init)
            .min { $0.rank < $1.rank }
            .map { MovieTrailer(youtubeKey: $0.key, name: $0.name) }
    }
}

/// A video TMDB listed that this app can actually play, with its place in the
/// preference order.
private struct PlayableVideo {
    let key: String
    let name: String
    let rank: Int

    init?(_ video: VideoDTO) {
        guard
            let key = video.key.nonEmpty,
            video.site?.caseInsensitiveCompare("YouTube") == .orderedSame,
            let kind = Kind(video.type)
        else { return nil }

        self.key = key
        self.name = video.name.nonEmpty ?? kind.fallbackName
        self.rank = kind.rawValue * 2 + (video.official == true ? 0 : 1)
    }

    private enum Kind: Int {
        case trailer = 0
        case teaser = 1

        init?(_ type: String?) {
            switch type?.lowercased() {
            case "trailer": self = .trailer
            case "teaser": self = .teaser
            default: return nil
            }
        }

        var fallbackName: String {
            switch self {
            case .trailer: "Trailer"
            case .teaser: "Teaser"
            }
        }
    }
}
