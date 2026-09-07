import Foundation
import DomainKit
import PresentationKit
@testable import MVP_App

/// Records what the presenter asked the screen to do.
///
/// No `UIView` anywhere: that a presenter can be driven this far without one is
/// the whole point of the split.
@MainActor
final class MoviesViewSpy: MoviesView {
    enum Overlay: Equatable {
        case loading
        case empty(isSearch: Bool)
        case failure(String, retry: Bool)
        case none
    }

    private(set) var items: [MovieCell.Model] = []
    private(set) var updates: [(index: Int, model: MovieCell.Model)] = []
    private(set) var overlay: Overlay = .none
    private(set) var overlays: [Overlay] = []
    private(set) var toasts: [String] = []
    private(set) var endRefreshingCount = 0
    private(set) var scrollToTopCount = 0
    private(set) var sourceEnabled = true
    private(set) var filterEnabled = true
    private(set) var shownFilter: MoviesFilter?
    private(set) var shownDetails: [Movie] = []
    private(set) var lastVisibleItemCalls = 0

    /// What the collection view would report. `nil` is "nothing on screen".
    var visibleItem: Int?

    func show(_ movies: [MovieCell.Model]) {
        items = movies
    }

    func updateItem(at index: Int, with model: MovieCell.Model) {
        updates.append((index, model))
        guard items.indices.contains(index) else { return }
        items[index] = model
    }

    func lastVisibleItem() -> Int? {
        lastVisibleItemCalls += 1
        return visibleItem
    }

    func showLoading() { record(.loading) }
    func showEmpty(isSearch: Bool) { record(.empty(isSearch: isSearch)) }
    func showFailure(_ message: String, retry: Bool) { record(.failure(message, retry: retry)) }
    func hideOverlay() { record(.none) }

    func showToast(_ message: String) { toasts.append(message) }
    func endRefreshing() { endRefreshingCount += 1 }
    func scrollToTop() { scrollToTopCount += 1 }

    func setInputsEnabled(source: Bool, filter: Bool) {
        sourceEnabled = source
        filterEnabled = filter
    }

    func showFilter(_ selection: MoviesFilter) { shownFilter = selection }
    func showDetails(for movie: Movie) { shownDetails.append(movie) }

    private func record(_ overlay: Overlay) {
        self.overlay = overlay
        overlays.append(overlay)
    }
}
