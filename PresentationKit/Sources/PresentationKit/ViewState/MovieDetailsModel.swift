import Foundation
import DomainKit

/// Everything the details screen draws, flat and already formatted.
///
/// A pure projection of the seed plus whatever has loaded. The rules about which
/// fields count as absent live here, where they can be tested without standing a
/// view up.
public struct MovieDetailsModel: Equatable {
    public let title: String
    public let posterURL: URL?
    public let backdropURL: URL?
    public let originalTitle: String?
    public let tagline: String?
    public let genres: String?
    public let year: String?
    public let runtime: String?
    public let rating: String?
    public let overview: String?
    /// The YouTube id, not a URL: the player takes an id.
    public let trailerKey: String?

    public init(
        title: String,
        posterURL: URL?,
        backdropURL: URL?,
        originalTitle: String?,
        tagline: String?,
        genres: String?,
        year: String?,
        runtime: String?,
        rating: String?,
        overview: String?,
        trailerKey: String?
    ) {
        self.title = title
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.originalTitle = originalTitle
        self.tagline = tagline
        self.genres = genres
        self.year = year
        self.runtime = runtime
        self.rating = rating
        self.overview = overview
        self.trailerKey = trailerKey
    }

    /// Year, runtime and rating on one line, or nil when none of them is known.
    public var metadata: String? {
        let parts = [year, runtime, rating].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension MovieDetailsModel {
    /// Loaded details win, the seed fills the gaps — so nothing already on
    /// screen can vanish when the request lands, and nothing waits for it that
    /// the list already knew.
    public init(movie: Movie, details: MovieDetails?, imageURLBuilder: any MovieImageURLBuilder) {
        let card = details.map { Card($0) } ?? Card(movie)
        let genreNames = (details?.genres ?? []).map(\.name)

        self.init(
            title: card.title,
            posterURL: imageURLBuilder.posterURL(path: card.posterPath),
            backdropURL: imageURLBuilder.backdropURL(path: card.backdropPath),
            // TMDB repeats `title` when a film has no distinct original title,
            // so showing it unconditionally would print the same line twice.
            originalTitle: details.flatMap { $0.originalTitle == $0.title ? nil : $0.originalTitle },
            tagline: details?.tagline,
            genres: genreNames.isEmpty ? nil : genreNames.joined(separator: ", "),
            year: MovieFormatting.year(card.releaseDate),
            runtime: MovieFormatting.runtime(minutes: details?.runtime),
            rating: MovieFormatting.rating(average: card.voteAverage, count: card.voteCount),
            // Not optional in the domain, but TMDB sends "" for a missing one.
            overview: card.overview.isEmpty ? nil : card.overview,
            trailerKey: details?.trailer?.youtubeKey
        )
    }
}

/// The fields `Movie` and `MovieDetails` both carry, taken from one side or the
/// other and never spliced.
///
/// `details?.releaseDate ?? movie.releaseDate` reads as "details wins" but means
/// "details wins unless it says no" — which puts the list's date under the
/// card's title, a record nobody published.
private struct Card {
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: Date?
    let voteAverage: Double
    let voteCount: Int

    init(_ movie: Movie) {
        title = movie.title
        overview = movie.overview
        posterPath = movie.posterPath
        backdropPath = movie.backdropPath
        releaseDate = movie.releaseDate
        voteAverage = movie.voteAverage
        voteCount = movie.voteCount
    }

    init(_ details: MovieDetails) {
        title = details.title
        overview = details.overview
        posterPath = details.posterPath
        backdropPath = details.backdropPath
        releaseDate = details.releaseDate
        voteAverage = details.voteAverage
        voteCount = details.voteCount
    }
}
