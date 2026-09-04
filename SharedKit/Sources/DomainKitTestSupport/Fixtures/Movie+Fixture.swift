import DomainKit
import Foundation

extension Movie {
    public static func fixture(
        id: Int = 1,
        title: String = "Fixture Movie",
        overview: String = "Fixture overview.",
        posterPath: String? = "/poster.jpg",
        backdropPath: String? = "/backdrop.jpg",
        releaseDate: Date? = Fixtures.referenceDate,
        voteAverage: Double = 7.5,
        voteCount: Int = 100,
        genreIDs: [Genre.ID] = [28]
    ) -> Movie {
        Movie(
            id: id,
            title: title,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIDs: genreIDs
        )
    }

    /// `count` movies with identifiers `startingAt..<startingAt + count`.
    public static func fixtures(count: Int, startingAt startID: Int = 1)
        -> [Movie]
    {
        (startID..<(startID + count)).map {
            .fixture(id: $0, title: "Fixture Movie \($0)")
        }
    }
}
