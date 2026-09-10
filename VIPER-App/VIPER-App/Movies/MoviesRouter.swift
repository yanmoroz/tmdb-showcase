import UIKit
import DomainKit
import PresentationKit

@MainActor
protocol MoviesRouterInput {
    func showFilter(_ selection: MoviesFilter)
    func showDetails(for movie: Movie)
}

/// `viewController` is `weak`: the view owns the presenter that owns this.
@MainActor
final class MoviesRouter: MoviesRouterInput {
    weak var viewController: UIViewController?

    func showFilter(_ selection: MoviesFilter) {}

    func showDetails(for movie: Movie) {}
}
