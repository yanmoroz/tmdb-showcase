import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import VIPER_App

@MainActor
@Suite("MoviesRouter")
struct MoviesRouterTests {
    @Test("The filter opens in a navigation stack of its own")
    func presentsTheFilterInItsOwnStack() {
        let host = PresentingViewControllerSpy()
        let sut = makeSUT(presentingFrom: host)

        sut.showFilter(MoviesFilter(), output: MoviesFilterModuleOutputSpy())

        let navigation = host.presented.first as? UINavigationController
        #expect(host.presented.count == 1)
        #expect(navigation?.viewControllers.first is MoviesFilterViewController)
    }

    @Test("A sheet already up is not opened twice")
    func doesNotStackSheets() {
        let host = PresentingViewControllerSpy()
        let sut = makeSUT(presentingFrom: host)
        let output = MoviesFilterModuleOutputSpy()

        sut.showFilter(MoviesFilter(), output: output)
        sut.showFilter(MoviesFilter(), output: output)

        #expect(host.presented.count == 1)
    }

    // MARK: - Helpers

    private func makeSUT(presentingFrom host: UIViewController) -> MoviesRouter {
        let sut = MoviesRouter(genres: GenresRepositoryStub())
        sut.viewController = host
        return sut
    }
}
