import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
@testable import MVC_App

/// The projection is pure, so the rules about which fields count as absent are
/// tested here without standing a view up.
@MainActor
@Suite("MovieDetailsViewController.Model")
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
        #expect(model.homepage == nil)
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

    @Test("Only a web address becomes a homepage link", arguments: [
        ("https://example.com", true),
        ("http://example.com", true),
        ("mailto:hello@example.com", false),
        ("ftp://example.com", false),
    ])
    func keepsOnlyWebHomepages(address: String, kept: Bool) {
        let model = makeModel(details: .fixture(homepage: URL(string: address)))

        #expect((model.homepage != nil) == kept)
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
    ) -> MovieDetailsViewController.Model {
        MovieDetailsViewController.Model(
            movie: movie,
            details: details,
            imageURLBuilder: MovieImageURLBuilderStub()
        )
    }
}

@MainActor
@Suite("MovieDetailsViewController")
final class MovieDetailsViewControllerTests {
    private weak var trackedSUT: MovieDetailsViewController?
    private var trackedLocation: SourceLocation?

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The details controller outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    @Test("Details are requested for the seeded movie")
    func requestsDetailsOnLoad() async throws {
        let (sut, fetchDetails) = makeSUT(movie: .fixture(id: 42))

        sut.loadViewIfNeeded()
        try await waitUntil { await fetchDetails.calls.map(\.id) == [42] }
    }

    /// The fattest mutant this screen can hide: a perfect projection that never
    /// reaches a label. Also pins that the seed draws before the request lands.
    @Test("The seeded title draws first, then the loaded one replaces it")
    func appliesTheModelToTheLabels() async throws {
        let (sut, _) = makeSUT(
            movie: .fixture(title: "Seeded Title"),
            details: .success(.fixture(title: "Loaded Title"))
        )

        sut.loadViewIfNeeded()
        #expect(sut.text(for: MovieDetailsViewController.Identifier.title) == "Seeded Title")

        try await waitUntil {
            sut.text(for: MovieDetailsViewController.Identifier.title) == "Loaded Title"
        }
    }

    @Test("A failure offers Retry, and retrying refetches")
    func retriesAfterFailure() async throws {
        let (sut, fetchDetails) = makeSUT(details: .failure(.network(.offline)))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.visibleStatus?.button.title == "Retry" }

        sut.reload()
        try await waitUntil { await fetchDetails.calls.count == 2 }
    }

    /// The regression guard for the mistake already made once on the filter
    /// screen: a screen-wide overlay would cover the seeded title and artwork,
    /// which did not fail and are the whole reason the screen is seeded.
    @Test("Nothing ever covers the seeded content", arguments: [
        Result<MovieDetails, AppError>.success(.fixture()),
        .failure(.network(.offline)),
        .failure(.regionRestricted),
    ])
    func neverUsesAScreenWideOverlay(details: Result<MovieDetails, AppError>) async throws {
        let (sut, fetchDetails) = makeSUT(details: details)

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchDetails.calls.isEmpty }
        await drainPendingWork()

        #expect(sut.currentUnavailableConfiguration == nil)
    }

    // MARK: - Factory

    private func makeSUT(
        movie: Movie = .fixture(),
        details: Result<MovieDetails, AppError> = .success(.fixture()),
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (sut: MovieDetailsViewController, fetchDetails: FetchMovieDetailsStub) {
        let fetchDetails = FetchMovieDetailsStub(result: details)
        let sut = MovieDetailsViewController(
            movie: movie,
            fetchDetails: fetchDetails,
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchDetails)
    }
}

@MainActor
private extension MovieDetailsViewController {
    /// The inline status view, or nil when it is hidden — the screen's own
    /// loading and failure surface, as opposed to a screen-wide one.
    var visibleStatus: UIContentUnavailableConfiguration? {
        autoreleasepool {
            guard
                let status = view.firstSubview(of: UIContentUnavailableView.self),
                !status.isHidden
            else { return nil }
            return status.configuration as? UIContentUnavailableConfiguration
        }
    }

    func text(for identifier: String) -> String? {
        autoreleasepool {
            view.firstSubview(of: UILabel.self, identifier: identifier)?.text
        }
    }

    var currentUnavailableConfiguration: UIContentUnavailableConfiguration? {
        autoreleasepool {
            setNeedsUpdateContentUnavailableConfiguration()
            view.layoutIfNeeded()
        }
        return contentUnavailableConfiguration as? UIContentUnavailableConfiguration
    }
}
