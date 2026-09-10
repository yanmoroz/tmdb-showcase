import UIKit
import DomainKit
import PresentationKit

/// How the filter sheet reports back to the screen that opened it.
@MainActor
protocol MoviesFilterModuleOutput: AnyObject {
    func didApplyFilter(_ filter: MoviesFilter)
}

@MainActor
protocol MoviesFilterRouterInput {
    func dismiss()
}

/// `viewController` is `weak`: the view owns the presenter that owns this.
@MainActor
final class MoviesFilterRouter: MoviesFilterRouterInput {
    weak var viewController: UIViewController?

    /// Assembles the sheet; the router that opens it decides how it appears.
    static func makeModule(
        fetchGenres: any FetchGenresUseCase,
        selection: MoviesFilter,
        output: any MoviesFilterModuleOutput
    ) -> MoviesFilterViewController {
        let interactor = MoviesFilterInteractor(fetchGenres: fetchGenres)
        let router = MoviesFilterRouter()
        let presenter = MoviesFilterPresenter(
            interactor: interactor,
            router: router,
            selection: selection,
            moduleOutput: output
        )
        let view = MoviesFilterViewController(presenter: presenter)

        presenter.view = view
        interactor.output = presenter
        router.viewController = view

        return view
    }

    func dismiss() {
        viewController?.dismiss(animated: true)
    }
}
