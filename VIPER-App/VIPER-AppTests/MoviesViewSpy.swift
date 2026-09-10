import Foundation
import PresentationKit
@testable import VIPER_App

/// Records what the presenter asked the screen to do.
@MainActor
final class MoviesViewSpy: MoviesView {
    enum Overlay: Equatable {
        case loading
        case empty(isSearch: Bool)
        case failure(String, retry: Bool)
        case none
    }

    private(set) var items: [MovieCell.Model] = []
    private(set) var overlay: Overlay = .none
    private(set) var toasts: [String] = []
    private(set) var endRefreshingCount = 0
    private(set) var scrollToTopCount = 0
    private(set) var sourceEnabled = true
    private(set) var filterEnabled = true
    private(set) var lastVisibleItemCalls = 0

    /// What the collection view would report. `nil` is "nothing on screen".
    var visibleItem: Int?

    func show(_ movies: [MovieCell.Model]) {
        items = movies
    }

    func updateItem(at index: Int, with model: MovieCell.Model) {
        guard items.indices.contains(index) else { return }
        items[index] = model
    }

    func lastVisibleItem() -> Int? {
        lastVisibleItemCalls += 1
        return visibleItem
    }

    func showLoading() { overlay = .loading }
    func showEmpty(isSearch: Bool) { overlay = .empty(isSearch: isSearch) }
    func showFailure(_ message: String, retry: Bool) { overlay = .failure(message, retry: retry) }
    func hideOverlay() { overlay = .none }

    func showToast(_ message: String) { toasts.append(message) }
    func endRefreshing() { endRefreshingCount += 1 }
    func scrollToTop() { scrollToTopCount += 1 }

    func setInputsEnabled(source: Bool, filter: Bool) {
        sourceEnabled = source
        filterEnabled = filter
    }
}
