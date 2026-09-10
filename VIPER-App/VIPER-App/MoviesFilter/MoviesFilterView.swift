import PresentationKit

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
}

/// What the filter sheet reports.
@MainActor
protocol MoviesFilterViewOutput {
    func viewDidLoad()

    func didSelectGenre(at index: Int)
    func didSelectSort(at index: Int)
    func didTapRetry()

    func didTapApply()
    func didTapCancel()
}
