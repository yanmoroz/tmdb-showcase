import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import DataKit
@testable import MVC_App

@MainActor
@Suite("CompositionRoot")
struct CompositionRootTests {
    /// Each tab owns its navigation controller: `showDetails(for:)` guards on
    /// being the top view controller, and a shared stack would break that.
    @Test("Both tabs get their own navigation stack")
    func buildsTwoTabs() {
        let tabBar = makeTabBar()

        #expect(tabBar.viewControllers?.count == 2)
        #expect(tabBar.viewControllers?.allSatisfy { $0 is UINavigationController } == true)
    }

    @Test("The tabs are Movies and Watchlist, in that order")
    func ordersTheTabs() throws {
        let roots = makeTabBar().viewControllers?
            .compactMap { ($0 as? UINavigationController)?.viewControllers.first }

        #expect(roots?.first is MoviesViewController)
        #expect(roots?.last is WatchlistViewController)
    }

    /// The stand-in the scene delegate uses when the store will not open: the
    /// app must still assemble.
    @Test("An unavailable watchlist still builds the app")
    func buildsWithoutAStore() {
        #expect(makeTabBar().viewControllers?.count == 2)
    }

    private func makeTabBar() -> UITabBarController {
        CompositionRoot.makeTabBar(
            movies: MoviesRepositoryStub(),
            genres: GenresRepositoryStub(),
            watchlist: UnavailableWatchlist(),
            imageURLBuilder: MovieImageURLBuilderStub()
        )
    }
}
