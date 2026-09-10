import UIKit
import DomainKit
import PresentationKit

@MainActor
protocol MoviesRouterInput {
    func showFilter(_ selection: MoviesFilter, output: any MoviesFilterModuleOutput)
    func showDetails(for movie: Movie)
}

/// Builds the modules this screen leads to and presents them from
/// `viewController`, which is `weak`: the view owns the presenter that owns this.
@MainActor
final class MoviesRouter: MoviesRouterInput {
    weak var viewController: UIViewController?

    private let genres: any GenresRepository

    init(genres: any GenresRepository) {
        self.genres = genres
    }

    func showFilter(_ selection: MoviesFilter, output: any MoviesFilterModuleOutput) {
        guard let viewController, viewController.presentedViewController == nil else { return }

        let filter = MoviesFilterRouter.makeModule(
            fetchGenres: FetchGenres(repository: genres),
            selection: selection,
            output: output
        )
        viewController.present(UINavigationController(rootViewController: filter), animated: true)
    }

    func showDetails(for movie: Movie) {}
}
