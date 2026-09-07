import PresentationKit

/// One row of either section, already decided: the view draws a title and a tick
/// and knows nothing about `Genre` or `MovieSortOption`.
struct FilterRow: Equatable {
    let title: String
    let isChecked: Bool
}

/// What the presenter may ask of the filter sheet.
///
/// The genre section carries its own load state as a single row rather than a
/// screen overlay: sorting does not depend on the catalogue, and covering the
/// whole sheet would take the sort options away too.
@MainActor
protocol MoviesFilterView: AnyObject {
    func showGenres(_ rows: [FilterRow])
    func showGenreLoading()
    func showGenreFailure(_ message: String, retry: Bool)

    func showSortOptions(_ rows: [FilterRow])

    func dismiss()
}
