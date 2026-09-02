import UIKit
import DomainKit

/// Owns the genre catalogue itself: the movies screen knows only the chosen
/// `Genre.ID`, so nobody pays for this request unless the filter is opened.
final class MoviesFilterViewController: UIViewController {
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

    private enum Section: Int, CaseIterable {
        case genre
        case sort
    }

    private let fetchGenres: any FetchGenresUseCase
    private let onApply: (MoviesFilter) -> Void

    private var selection: MoviesFilter
    private var catalogue: Catalogue = .loaded([.any]) {
        didSet { tableView.reloadData() }
    }

    private lazy var tableView = makeTableView()

    init(
        fetchGenres: any FetchGenresUseCase,
        selection: MoviesFilter,
        onApply: @escaping (MoviesFilter) -> Void
    ) {
        self.fetchGenres = fetchGenres
        self.selection = selection
        self.onApply = onApply
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVC-App builds its UI in code")
    }

    deinit {
        if case .loading(let task) = catalogue {
            task.cancel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Filter"
        view.backgroundColor = .systemGroupedBackground
        setUpSubviews()
        setUpNavigationItems()
        loadCatalogue()
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
            }
        )
    }

    private var genreRows: [GenreRow] {
        if case .loaded(let rows) = catalogue { rows } else { [] }
    }

    // MARK: - Genre section state

    /// The genre section carries its own load state as a single row. A
    /// controller-level `contentUnavailableConfiguration` would cover the whole
    /// view, and sorting does not depend on the catalogue.
    private var showsGenreStatusRow: Bool {
        if case .loaded = catalogue { false } else { true }
    }

    private var genreStatusConfiguration: UIContentUnavailableConfiguration? {
        switch catalogue {
        case .loading: .loading()
        case .failed(let error): failureConfiguration(error)
        case .loaded: nil
        }
    }

    private func failureConfiguration(_ error: AppError) -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "Couldn't load genres"
        configuration.secondaryText = error.message

        var button = UIButton.Configuration.borderless()
        button.title = "Retry"
        configuration.button = button
        configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
            self?.loadCatalogue()
        }
        return configuration
    }

    // MARK: - Layout

    private func setUpSubviews() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setUpNavigationItems() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Apply",
            primaryAction: UIAction { [weak self] _ in self?.apply() }
        )
    }

    private func makeTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }

    private static let cellIdentifier = "FilterCell"

    private func apply() {
        onApply(selection)
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource

extension MoviesFilterViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section.allCases[section] {
        case .genre: showsGenreStatusRow ? 1 : genreRows.count
        case .sort: MovieSortOption.allCases.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section.allCases[section] {
        case .genre: "Genre"
        case .sort: "Sort"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)

        if Section.allCases[indexPath.section] == .genre, let status = genreStatusConfiguration {
            cell.contentConfiguration = status
            cell.accessoryType = .none
            cell.selectionStyle = .none
            return cell
        }

        var content = cell.defaultContentConfiguration()

        switch Section.allCases[indexPath.section] {
        case .genre:
            let row = genreRows[indexPath.row]
            content.text = row.title
            cell.accessoryType = selection.genreID == row.id ? .checkmark : .none

        case .sort:
            let option = MovieSortOption.allCases[indexPath.row]
            content.text = option.title
            cell.accessoryType = selection.sort == option ? .checkmark : .none
        }

        cell.contentConfiguration = content
        cell.selectionStyle = .default
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MoviesFilterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = Section.allCases[indexPath.section]
        if section == .genre, showsGenreStatusRow { return }

        let previous = checkedRow(in: section)

        switch section {
        case .genre: selection.genreID = genreRows[indexPath.row].id
        case .sort: selection.sort = MovieSortOption.allCases[indexPath.row]
        }

        var affected = [indexPath]
        if let previous, previous != indexPath {
            affected.append(previous)
        }

        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: affected, with: .none)
    }

    /// Where the checkmark currently sits, so moving it can reload two rows
    /// instead of the whole section.
    private func checkedRow(in section: Section) -> IndexPath? {
        let row: Int? = switch section {
        case .genre: genreRows.firstIndex { $0.id == selection.genreID }
        case .sort: MovieSortOption.allCases.firstIndex(of: selection.sort)
        }
        return row.map { IndexPath(row: $0, section: section.rawValue) }
    }
}
