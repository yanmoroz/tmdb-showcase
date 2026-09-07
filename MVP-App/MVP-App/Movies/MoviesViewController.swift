import UIKit
import DomainKit
import PresentationKit

/// Draws what the presenter sends and reports what the reader does. It holds no
/// query, no page cursor and no `Task`.
final class MoviesViewController: UIViewController {
    private let presenter: MoviesPresenter
    /// Composition supplies the destination; this controller supplies the
    /// presentation. `makeDetails` is optional only until that screen exists.
    private let makeFilter: (MoviesFilter, @escaping (MoviesFilter) -> Void) -> UIViewController
    private let makeDetails: (Movie) -> UIViewController?

    private var items: [MovieCell.Model] = []

    private lazy var collectionView = makeCollectionView()
    private let refreshControl = UIRefreshControl()
    private lazy var filterItem = makeFilterItem()
    private lazy var sourceControl = makeSourceControl()

    private var overlay: UIContentUnavailableConfiguration?

    init(
        presenter: MoviesPresenter,
        makeFilter: @escaping (MoviesFilter, @escaping (MoviesFilter) -> Void) -> UIViewController,
        makeDetails: @escaping (Movie) -> UIViewController?
    ) {
        self.presenter = presenter
        self.makeFilter = makeFilter
        self.makeDetails = makeDetails
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVP-App builds its UI in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Movies"
        view.backgroundColor = .systemBackground
        setUpSubviews()
        setUpSearch()
        navigationItem.titleView = sourceControl
        navigationItem.rightBarButtonItem = filterItem
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }

    // MARK: - Unavailable content

    override func updateContentUnavailableConfiguration(
        using state: UIContentUnavailableConfigurationState
    ) {
        contentUnavailableConfiguration = overlay
    }

    private func setOverlay(_ configuration: UIContentUnavailableConfiguration?) {
        overlay = configuration
        setNeedsUpdateContentUnavailableConfiguration()
    }

    // MARK: - Layout

    private func setUpSubviews() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeCollectionView() -> UICollectionView {
        let collectionView = MovieGrid.makeCollectionView()
        collectionView.dataSource = self
        collectionView.delegate = self
        return collectionView
    }

    private func setUpSearch() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        // Results are drawn in the same list, so dimming it on focus would hide
        // the very thing the search is filtering.
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search movies"
        // Film titles are proper nouns in every language TMDB carries, so the
        // keyboard must not second-guess them.
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    private func makeSourceControl() -> UISegmentedControl {
        let sources = MoviesFilter.Source.allCases
        let control = UISegmentedControl(items: sources.map(\.title))
        control.selectedSegmentIndex = 0

        control.addAction(
            UIAction { [weak self, weak control] _ in
                guard let control, control.selectedSegmentIndex != UISegmentedControl.noSegment else { return }
                self?.presenter.didChangeSource(sources[control.selectedSegmentIndex])
            },
            for: .valueChanged
        )
        return control
    }

    private func makeFilterItem() -> UIBarButtonItem {
        UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            primaryAction: UIAction { [weak self] _ in self?.presenter.didTapFilter() }
        )
    }

    @objc private func refreshTriggered() {
        presenter.didPullToRefresh()
    }
}

// MARK: - MoviesView

extension MoviesViewController: MoviesView {
    func show(_ movies: [MovieCell.Model]) {
        items = movies
        // reloadData rather than insertItems: a batch update needs the collection
        // view to have recounted itself after the previous reloadData. Between
        // pull-to-refresh and the network response a layout pass may not happen,
        // and insertItems then trips Invalid_Batch_Updates. Content only grows at
        // the end, and reloadData keeps contentOffset.
        collectionView.reloadData()
    }

    func updateItem(at index: Int, with model: MovieCell.Model) {
        guard items.indices.contains(index) else { return }
        items[index] = model

        // One cell, in place. A batch update here would meet the same recount
        // problem `show(_:)` documents.
        let indexPath = IndexPath(item: index, section: 0)
        guard let cell = collectionView.cellForItem(at: indexPath) as? MovieCell else { return }
        cell.configure(with: model)
    }

    /// `nil` when nothing is on screen — distinct from item 0 being visible.
    func lastVisibleItem() -> Int? {
        collectionView.indexPathsForVisibleItems.map(\.item).max()
    }

    func showLoading() {
        setOverlay(.loading())
    }

    func showEmpty(isSearch: Bool) {
        // The first-party search preset writes its own text, localised to the
        // device — the reason a bespoke empty-state view was dropped earlier.
        guard !isSearch else {
            setOverlay(.search())
            return
        }

        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "film")
        configuration.text = "No movies"
        configuration.secondaryText = "Nothing to show here."
        setOverlay(configuration)
    }

    func showFailure(_ message: String, retry: Bool) {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "Couldn't load"
        configuration.secondaryText = message

        if retry {
            var button = UIButton.Configuration.borderless()
            button.title = "Retry"
            configuration.button = button
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                self?.presenter.didTapRetry()
            }
        }
        setOverlay(configuration)
    }

    func hideOverlay() {
        setOverlay(nil)
    }

    func showToast(_ message: String) {
        ToastView.show(message, in: view)
    }

    func endRefreshing() {
        refreshControl.endRefreshing()
    }

    func scrollToTop() {
        // `.zero` is not the top: the search bar and safe area push it down by
        // the adjusted inset.
        collectionView.setContentOffset(
            CGPoint(x: 0, y: -collectionView.adjustedContentInset.top),
            animated: false
        )
    }

    func setInputsEnabled(source: Bool, filter: Bool) {
        sourceControl.isEnabled = source
        filterItem.isEnabled = filter
    }

    func showFilter(_ selection: MoviesFilter) {
        guard presentedViewController == nil else { return }

        let filter = makeFilter(selection) { [weak self] filter in
            self?.presenter.didApplyFilter(filter)
        }
        present(UINavigationController(rootViewController: filter), animated: true)
    }

    func showDetails(for movie: Movie) {
        guard navigationController?.topViewController === self else { return }
        guard let details = makeDetails(movie) else { return }
        navigationController?.pushViewController(details, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension MoviesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MovieCell.reuseIdentifier,
            for: indexPath
        )
        if let cell = cell as? MovieCell {
            cell.configure(with: items[indexPath.item])
            cell.onToggleWatchlist = { [weak self] in
                self?.presenter.didToggleWatchlist(at: indexPath.item)
            }
        }
        return cell
    }
}

// MARK: - UISearchResultsUpdating

extension MoviesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        presenter.searchTextChanged(searchController.searchBar.text ?? "")
    }
}

// MARK: - UICollectionViewDelegate

extension MoviesViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        presenter.willDisplayItem(at: indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        presenter.didSelectItem(at: indexPath.item)
    }
}
