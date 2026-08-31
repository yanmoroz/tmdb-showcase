import Foundation
import DomainKit

extension MovieDetails {
    public static func fixture(
        id: Int = 1,
        title: String = "Fixture Movie",
        originalTitle: String = "Fixture Movie",
        tagline: String? = "Fixture tagline",
        overview: String = "Fixture overview.",
        posterPath: String? = "/poster.jpg",
        backdropPath: String? = "/backdrop.jpg",
        releaseDate: Date? = Fixtures.referenceDate,
        runtime: Int? = 120,
        voteAverage: Double = 7.5,
        voteCount: Int = 100,
        genres: [Genre] = [.fixture()],
        homepage: URL? = nil
    ) -> MovieDetails {
        MovieDetails(
            id: id,
            title: title,
            originalTitle: originalTitle,
            tagline: tagline,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            runtime: runtime,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genres: genres,
            homepage: homepage
        )
    }
}
