import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import PresentationKit

/// The projection is pure, so the rules about which fields count as absent are
/// tested here without standing a view up.
@Suite("MovieDetailsModel")
struct MovieDetailsModelTests {
    @Test("The seed alone already fills the screen")
    func projectsSeedAlone() {
        let model = makeModel(details: nil)

        #expect(model.title == "Fixture Movie")
        #expect(model.year == "2001")
        #expect(model.rating == "★ 7.5")
        #expect(model.overview == "Fixture overview.")
        #expect(model.posterURL != nil)
        // Only these need the request.
        #expect(model.tagline == nil)
        #expect(model.genres == nil)
        #expect(model.runtime == nil)
    }

    @Test("Loaded details win over the seed")
    func loadedDetailsWin() {
        let model = makeModel(details: .fixture(title: "Loaded Title", runtime: 126))

        #expect(model.title == "Loaded Title")
        #expect(model.runtime == "2h 6m")
    }

    /// TMDB repeats `title` when a film has no distinct original title, so
    /// showing it unconditionally would print the same line twice.
    @Test("An original title identical to the title is not shown")
    func hidesRedundantOriginalTitle() {
        let model = makeModel(details: .fixture(title: "Dune", originalTitle: "Dune"))

        #expect(model.originalTitle == nil)
    }

    @Test("A distinct original title is shown")
    func showsDistinctOriginalTitle() {
        let model = makeModel(details: .fixture(title: "The Odyssey", originalTitle: "Odysseia"))

        #expect(model.originalTitle == "Odysseia")
    }

    /// `overview` is not optional in the domain, but TMDB sends "" for a
    /// missing one — an empty paragraph is not a paragraph.
    @Test("An empty overview is absent, not blank")
    func treatsEmptyOverviewAsAbsent() {
        let model = makeModel(movie: .fixture(overview: ""), details: .fixture(overview: ""))

        #expect(model.overview == nil)
    }

    /// `details?.releaseDate ?? movie.releaseDate` reads as "details wins" but
    /// means "unless it says no", which shows the list's year under the card's
    /// title — a record nobody published.
    @Test("A card with no release date does not borrow the seed's year")
    func neverSplicesTwoRecords() {
        let model = makeModel(
            movie: .fixture(releaseDate: Date(timeIntervalSince1970: 1_609_459_200)),
            details: .fixture(releaseDate: nil)
        )

        #expect(model.year == nil)
    }

    @Test("Genres are joined, and absent when there are none")
    func joinsGenres() {
        let listed = makeModel(details: .fixture(genres: [.fixture(id: 28, name: "Action"), .fixture(id: 18, name: "Drama")]))
        let none = makeModel(details: .fixture(genres: []))

        #expect(listed.genres == "Action, Drama")
        #expect(none.genres == nil)
    }

    private func makeModel(
        movie: Movie = .fixture(),
        details: MovieDetails?
    ) -> MovieDetailsModel {
        MovieDetailsModel(
            movie: movie,
            details: details,
            imageURLBuilder: MovieImageURLBuilderStub()
        )
    }
}
