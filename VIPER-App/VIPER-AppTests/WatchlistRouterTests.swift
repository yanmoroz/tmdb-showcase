import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import DataKit
@testable import VIPER_App

@MainActor
@Suite("WatchlistRouter")
struct WatchlistRouterTests {
    @Test("Details are pushed onto the watchlist's own stack")
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

    private func makeSUT(from host: UIViewController) -> WatchlistRouter {
        let sut = WatchlistRouter(
            movies: MoviesRepositoryStub(),
            watchlist: UnavailableWatchlistRepository(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        sut.viewController = host
        return sut
    }
}
