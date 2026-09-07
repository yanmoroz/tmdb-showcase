import UIKit
import PresentationKit

/// Two sections of titles with a tick. Which title, and where the tick sits, is
/// the presenter's business.
final class MoviesFilterViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case genre
        case sort
    }

    /// The genre section is either rows or a single status cell.
    private enum GenreContent {
        case rows([FilterRow])
        case status(UIContentUnavailableConfiguration)
    }

    private let presenter: MoviesFilterPresenter

    private var genreContent: GenreContent = .rows([])
    private var sortRows: [FilterRow] = []

    private lazy var tableView = makeTableView()

    init(presenter: MoviesFilterPresenter) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVP-App builds its UI in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Filter"
        view.backgroundColor = .systemGroupedBackground
        setUpSubviews()
        setUpNavigationItems()
        presenter.viewDidLoad()
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
            primaryAction: UIAction { [weak self] _ in self?.presenter.didTapCancel() }
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Apply",
            primaryAction: UIAction { [weak self] _ in self?.presenter.didTapApply() }
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
}

// MARK: - MoviesFilterView

extension MoviesFilterViewController: MoviesFilterView {
    func showGenres(_ rows: [FilterRow]) {
        genreContent = .rows(rows)
        reload(.genre)
    }

    func showGenreLoading() {
        genreContent = .status(.loading())
        reload(.genre)
    }

    func showGenreFailure(_ message: String, retry: Bool) {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "Couldn't load genres"
        configuration.secondaryText = message

        if retry {
            var button = UIButton.Configuration.borderless()
            button.title = "Retry"
            configuration.button = button
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                self?.presenter.didTapRetry()
            }
        }
        genreContent = .status(configuration)
        reload(.genre)
    }

    func showSortOptions(_ rows: [FilterRow]) {
        sortRows = rows
        reload(.sort)
    }

    func dismiss() {
        dismiss(animated: true)
    }

    /// The whole section rather than the two rows whose tick moved: at twenty
    /// rows the difference is invisible, and the presenter sends rows without
    /// saying which changed.
    private func reload(_ section: Section) {
        guard tableView.numberOfSections > section.rawValue else {
            tableView.reloadData()
            return
        }
        tableView.reloadSections(IndexSet(integer: section.rawValue), with: .none)
    }
}

// MARK: - UITableViewDataSource

extension MoviesFilterViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section.allCases[section] {
        case .genre:
            switch genreContent {
            case .rows(let rows): rows.count
            case .status: 1
            }
        case .sort:
            sortRows.count
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

        if Section.allCases[indexPath.section] == .genre, case .status(let status) = genreContent {
            cell.contentConfiguration = status
            cell.accessoryType = .none
            cell.selectionStyle = .none
            return cell
        }

        let row = switch Section.allCases[indexPath.section] {
        case .genre: genreRow(at: indexPath.row)
        case .sort: sortRows[indexPath.row]
        }

        var content = cell.defaultContentConfiguration()
        content.text = row.title
        cell.contentConfiguration = content
        cell.accessoryType = row.isChecked ? .checkmark : .none
        cell.selectionStyle = .default
        return cell
    }

    private func genreRow(at index: Int) -> FilterRow {
        guard case .rows(let rows) = genreContent else {
            preconditionFailure("A genre row was asked for while the section shows a status")
        }
        return rows[index]
    }
}

// MARK: - UITableViewDelegate

extension MoviesFilterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section.allCases[indexPath.section] {
        case .genre:
            guard case .rows = genreContent else { return }
            presenter.didSelectGenre(at: indexPath.row)
        case .sort:
            presenter.didSelectSort(at: indexPath.row)
        }
    }
}
