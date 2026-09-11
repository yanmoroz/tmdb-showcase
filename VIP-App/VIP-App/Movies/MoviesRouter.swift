import UIKit

@MainActor
protocol MoviesRoutingLogic {
    func routeToFilter()
    func routeToDetails()
}

@MainActor
protocol MoviesDataPassing {
    var dataStore: any MoviesDataStore { get }
}

/// `viewController` is `weak`: the view owns this router.
@MainActor
final class MoviesRouter: MoviesRoutingLogic, MoviesDataPassing {
    weak var viewController: UIViewController?

    let dataStore: any MoviesDataStore

    init(dataStore: any MoviesDataStore) {
        self.dataStore = dataStore
    }

    func routeToFilter() {}

    func routeToDetails() {}
}
