import Foundation
import DomainKit
import PresentationKit

/// Owns the genre catalogue itself: the movies screen knows only the chosen
/// `Genre.ID`, so nobody pays for this request unless the filter is opened.
@MainActor
final class MoviesFilterPresenter {
    weak var view: (any MoviesFilterView)?

    private enum Catalogue {
        case loading(Task<Void, Never>)
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

    private let fetchGenres: any FetchGenresUseCase
    private let onApply: (MoviesFilter) -> Void

    private var selection: MoviesFilter
    private var catalogue: Catalogue = .loaded([.any])

    init(
        fetchGenres: any FetchGenresUseCase,
        selection: MoviesFilter,
        onApply: @escaping (MoviesFilter) -> Void
    ) {
        self.fetchGenres = fetchGenres
        self.selection = selection
        self.onApply = onApply
    }

    deinit {
        if case .loading(let task) = catalogue {
            task.cancel()
        }
    }

    // MARK: - Lifecycle

    func viewDidLoad() {
        showSortOptions()
        loadCatalogue()
    }

    // MARK: - Input

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
        onApply(selection)
        view?.dismiss()
    }

    func didTapCancel() {
        view?.dismiss()
    }

    // MARK: - Catalogue

    private func loadCatalogue() {
        if case .loading(let task) = catalogue {
            task.cancel()
        }

        catalogue = .loading(
            Task { [weak self] in
                guard let self else { return }

                let outcome: Result<[Genre], AppError>
                do {
                    outcome = .success(try await fetchGenres())
                } catch let error as AppError {
                    outcome = .failure(error)
                } catch {
                    outcome = .failure(.unknown)
                }

                guard !Task.isCancelled else { return }

                switch outcome {
                case .success(let genres): catalogue = .loaded([.any] + genres.map(GenreRow.genre))
                case .failure(let error): catalogue = .failed(error)
                }
                showGenres()
            }
        )
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
