import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import DataKit
@testable import VIPER_App

@MainActor
@Suite("MovieDetailsRouter")
struct MovieDetailsRouterTests {
    /// Details leads nowhere, so there is no router to hold: two `weak`
    /// references instead of three.
    @Test("The details module is wired both ways")
    func moduleIsWiredBothWays() throws {
        let view = makeModule()
        let presenter = try #require(view.presenter as? MovieDetailsPresenter)
        let interactor = try #require(presenter.interactor as? MovieDetailsInteractor)

        #expect(presenter.view === view)
        #expect(interactor.output === presenter)
    }

    @Test("The film it was handed draws before anything loads")
    func seedDrawsOnLoad() {
        let view = makeModule(movie: .fixture(id: 1, title: "Dune"))

        view.loadViewIfNeeded()

        #expect(view.testTitleText == "Dune")
    }

    // MARK: - Helpers

    private func makeModule(movie: Movie = .fixture(id: 1)) -> MovieDetailsViewController {
        MovieDetailsRouter.makeModule(
            movie: movie,
            movies: MoviesRepositoryStub(),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
    }
}

@MainActor
private extension MovieDetailsViewController {
    var testTitleText: String? {
        autoreleasepool {
            view.firstSubview(of: UILabel.self, identifier: Identifier.title)?.text
        }
    }
}
