import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import DataKit
import PresentationKit
@testable import VIPER_App

@MainActor
@Suite("MoviesRouter")
struct MoviesRouterTests {
    // MARK: - Filter

    @Test("The filter opens in a navigation stack of its own")
    func presentsTheFilterInItsOwnStack() {
        let host = PresentingViewControllerSpy()
        let sut = makeSUT(from: host)

        sut.showFilter(MoviesFilter(), output: MoviesFilterModuleOutputSpy())

        let navigation = host.presented.first as? UINavigationController
        #expect(host.presented.count == 1)
        #expect(navigation?.viewControllers.first is MoviesFilterViewController)
    }

    @Test("A sheet already up is not opened twice")
    func doesNotStackSheets() {
        let host = PresentingViewControllerSpy()
        let sut = makeSUT(from: host)
        let output = MoviesFilterModuleOutputSpy()

        sut.showFilter(MoviesFilter(), output: output)
        sut.showFilter(MoviesFilter(), output: output)

        #expect(host.presented.count == 1)
    }

    // MARK: - Details

    @Test("Details are pushed onto the list's own stack")
    func pushesDetails() {
        let host = UIViewController()
        let navigation = ImmediateNavigationController(rootViewController: host)
        let sut = makeSUT(from: host)

        sut.showDetails(for: .fixture(id: 7))

        #expect(navigation.viewControllers.count == 2)
        #expect(navigation.viewControllers.last is MovieDetailsViewController)
    }

    @Test("Details are not pushed from a screen that is not on top")
    func pushesOnlyFromTheTop() {
        let host = UIViewController()
        let navigation = ImmediateNavigationController(rootViewController: host)
        navigation.pushViewController(UIViewController(), animated: false)
        let sut = makeSUT(from: host)

        sut.showDetails(for: .fixture(id: 7))

        #expect(navigation.viewControllers.count == 2)
        #expect(!(navigation.viewControllers.last is MovieDetailsViewController))
    }

    // MARK: - Helpers

    private func makeSUT(from host: UIViewController) -> MoviesRouter {
        let sut = MoviesRouter(
            movies: MoviesRepositoryStub(),
            genres: GenresRepositoryStub(),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        sut.viewController = host
        return sut
    }
}
