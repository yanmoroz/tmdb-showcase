import Foundation
import DomainKit
import PresentationKit

/// Owns the genre catalogue itself: the movies screen knows only the chosen
/// `Genre.ID`, so nobody pays for this request unless the filter is opened.
@MainActor
final class MoviesFilterPresenter {
    weak var view: (any MoviesFilterView)?

    let interactor: any MoviesFilterInteractorInput
    let router: any MoviesFilterRouterInput
    /// `weak` so the sheet never keeps the screen that opened it alive.
    private weak var moduleOutput: (any MoviesFilterModuleOutput)?

    /// `.loading` carries no `Task`, as on the movies screen: the request is the
    /// interactor's.
    private enum Catalogue {
        case loading
        case loaded([GenreRow])
        case failed(AppError)
    }

    /// "Any genre" is a case rather than an absent `Genre`: it is a row the
    /// interface offers, not a domain value that failed to arrive.
    private enum GenreRow {
        case any
        case genre(Genre)

        var title: String {
            switch self {
            case .any: "All"
            case .genre(let genre): genre.name
            }
        }

        var id: Genre.ID? {
            switch self {
            case .any: nil
            case .genre(let genre): genre.id
            }
        }
    }

    private var selection: MoviesFilter
    private var catalogue: Catalogue = .loaded([.any])

    init(
        interactor: any MoviesFilterInteractorInput,
        router: any MoviesFilterRouterInput,
        selection: MoviesFilter,
        moduleOutput: any MoviesFilterModuleOutput
    ) {
        self.interactor = interactor
        self.router = router
        self.selection = selection
        self.moduleOutput = moduleOutput
    }

    // MARK: - Catalogue

    private func loadCatalogue() {
        catalogue = .loading
        interactor.loadGenres()
        showGenres()
    }

    private var genreRows: [GenreRow] {
        if case .loaded(let rows) = catalogue { rows } else { [] }
    }

    // MARK: - Rendering

    private func showGenres() {
        switch catalogue {
        case .loading:
            view?.showGenreLoading()
        case .failed(let error):
            // As on the movies and details screens: a geo-block returns the same
            // 403 however many times it is asked, so offering the button would be
            // a dead end. Cancellation is not retryable either, but retrying is
            // the only move left when nothing arrived.
            view?.showGenreFailure(error.message, retry: error.isRetryable || error == .cancelled)
        case .loaded(let rows):
            view?.showGenres(
                rows.map { FilterRow(title: $0.title, isChecked: $0.id == selection.genreID) }
            )
        }
    }

    private func showSortOptions() {
        view?.showSortOptions(
            MovieSortOption.allCases.map {
                FilterRow(title: $0.title, isChecked: $0 == selection.sort)
            }
        )
    }
}

// MARK: - MoviesFilterViewOutput

extension MoviesFilterPresenter: MoviesFilterViewOutput {
    func viewDidLoad() {
        showSortOptions()
        loadCatalogue()
    }

    func didSelectGenre(at index: Int) {
        guard genreRows.indices.contains(index) else { return }
        selection.genreID = genreRows[index].id
        showGenres()
    }

    func didSelectSort(at index: Int) {
        guard MovieSortOption.allCases.indices.contains(index) else { return }
        selection.sort = MovieSortOption.allCases[index]
        showSortOptions()
    }

    func didTapRetry() {
        loadCatalogue()
    }

    func didTapApply() {
        moduleOutput?.didApplyFilter(selection)
        router.dismiss()
    }

    func didTapCancel() {
        router.dismiss()
    }
}

// MARK: - MoviesFilterInteractorOutput

extension MoviesFilterPresenter: MoviesFilterInteractorOutput {
    func didLoadGenres(_ genres: [Genre]) {
        catalogue = .loaded([.any] + genres.map(GenreRow.genre))
        showGenres()
    }

    func didFailToLoadGenres(with error: AppError) {
        catalogue = .failed(error)
        showGenres()
    }
}
