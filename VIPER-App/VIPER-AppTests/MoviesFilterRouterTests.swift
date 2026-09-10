import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import VIPER_App

@MainActor
@Suite("MoviesFilterRouter")
struct MoviesFilterRouterTests {
    /// The same three `weak` references as every module. The fourth, the screen
    /// the sheet reports to, goes in through the presenter's `init`.
    @Test("The filter module is wired every way")
    func moduleIsWiredEveryWay() throws {
        let view = MoviesFilterRouter.makeModule(
            fetchGenres: FetchGenresStub(),
            selection: MoviesFilter(),
            output: MoviesFilterModuleOutputSpy()
        )
        let presenter = try #require(view.presenter as? MoviesFilterPresenter)
        let interactor = try #require(presenter.interactor as? MoviesFilterInteractor)
        let router = try #require(presenter.router as? MoviesFilterRouter)

        #expect(presenter.view === view)
        #expect(interactor.output === presenter)
        #expect(router.viewController === view)
    }

    @Test("Apply hands back the selection the sheet was opened with")
    func appliesWhatItWasHanded() {
        let output = MoviesFilterModuleOutputSpy()
        let selection = MoviesFilter(genreID: 28, sort: .ratingDescending)
        let view = MoviesFilterRouter.makeModule(
            fetchGenres: FetchGenresStub(),
            selection: selection,
            output: output
        )

        view.loadViewIfNeeded()
        view.navigationItem.rightBarButtonItem?.primaryAction?.performWithSender(nil, target: nil)

        #expect(output.applied == [selection])
    }

    @Test("Dismissing closes the sheet")
    func dismissesTheSheet() {
        let host = PresentingViewControllerSpy()
        let router = MoviesFilterRouter()
        router.viewController = host

        router.dismiss()

        #expect(host.dismissCount == 1)
    }
}
