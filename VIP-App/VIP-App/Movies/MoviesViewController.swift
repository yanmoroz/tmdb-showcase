import UIKit
import PresentationKit

/// What the presenter may ask of the movies screen.
@MainActor
protocol MoviesDisplayLogic: AnyObject {
    func displayFeed(_ viewModel: MoviesModels.ViewModel.Feed)
    func displayItem(_ viewModel: MoviesModels.ViewModel.Item)
    func displayOverlay(_ viewModel: MoviesModels.ViewModel.Overlay)

    func displayToast(_ viewModel: MoviesModels.ViewModel.Toast)
    func displayInputAvailability(_ viewModel: MoviesModels.ViewModel.InputAvailability)

    func displayRefreshEnded(_ viewModel: MoviesModels.ViewModel.RefreshEnded)
    func displayScrollToTop(_ viewModel: MoviesModels.ViewModel.ScrollToTop)
    func displayMovieSelection(_ viewModel: MoviesModels.ViewModel.MovieSelection)
}

/// Sends what the reader does to the interactor and draws what the presenter
/// sends back. It holds no query, no page cursor and no `Task`.
final class MoviesViewController: UIViewController {
    let interactor: any MoviesBusinessLogic
    let router: any MoviesRoutingLogic

    private var items: [MovieCell.Model] = []

    private lazy var collectionView = makeCollectionView()
    private let refreshControl = UIRefreshControl()
    private lazy var filterItem = makeFilterItem()
    private lazy var sourceControl = makeSourceControl()

    private var overlay: UIContentUnavailableConfiguration?

    init(interactor: any MoviesBusinessLogic, router: any MoviesRoutingLogic) {
        self.interactor = interactor
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — VIP-App builds its UI in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Movies"
        view.backgroundColor = .systemBackground
        setUpSubviews()
        setUpSearch()
        navigationItem.titleView = sourceControl
        navigationItem.rightBarButtonItem = filterItem
        interactor.start(.init())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        interactor.reloadSavedIDs(.init())
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
                self?.interactor.changeSource(.init(source: sources[control.selectedSegmentIndex]))
            },
            for: .valueChanged
        )
        return control
    }

    private func makeFilterItem() -> UIBarButtonItem {
        UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            primaryAction: UIAction { [weak self] _ in self?.router.routeToFilter() }
        )
    }

    @objc private func refreshTriggered() {
        interactor.reload(.init())
    }

    private func show(_ movies: [MovieCell.Model]) {
        items = movies
        // reloadData rather than insertItems: a batch update needs the collection
        // view to have recounted itself after the previous reloadData. Between
        // pull-to-refresh and the network response a layout pass may not happen,
        // and insertItems then trips Invalid_Batch_Updates. Content only grows at
        // the end, and reloadData keeps contentOffset.
        // It also re-displays the cells on screen at the next layout, so
        // willDisplay fires for them again once a page lands. That is what keeps
        // a reader already at the bottom paginating: those cells found a load in
        // progress while the page was in flight, and nothing new scrolls into
        // view on its own.
        collectionView.reloadData()
    }
}

// MARK: - MoviesDisplayLogic

extension MoviesViewController: MoviesDisplayLogic {
    func displayFeed(_ viewModel: MoviesModels.ViewModel.Feed) {
        show(viewModel.items)
    }

    func displayItem(_ viewModel: MoviesModels.ViewModel.Item) {
        guard items.indices.contains(viewModel.index) else { return }
        items[viewModel.index] = viewModel.item

        // One cell, in place. A batch update here would meet the same recount
        // problem `show(_:)` documents.
        let indexPath = IndexPath(item: viewModel.index, section: 0)
        guard let cell = collectionView.cellForItem(at: indexPath) as? MovieCell else { return }
        cell.configure(with: viewModel.item)
    }

    func displayOverlay(_ viewModel: MoviesModels.ViewModel.Overlay) {
        switch viewModel {
        case .loading:
            setOverlay(.loading())

        case .empty(let isSearch):
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

        case .failure(let message, let retry):
            var configuration = UIContentUnavailableConfiguration.empty()
            configuration.image = UIImage(systemName: "exclamationmark.triangle")
            configuration.text = "Couldn't load"
            configuration.secondaryText = message

            if retry {
                var button = UIButton.Configuration.borderless()
                button.title = "Retry"
                configuration.button = button
                configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                    self?.interactor.reload(.init())
                }
            }
            setOverlay(configuration)

        case .hidden:
            setOverlay(nil)
        }
    }

    func displayToast(_ viewModel: MoviesModels.ViewModel.Toast) {
        ToastView.show(viewModel.message, in: view)
    }

    func displayInputAvailability(_ viewModel: MoviesModels.ViewModel.InputAvailability) {
        sourceControl.isEnabled = viewModel.sourceEnabled
        filterItem.isEnabled = viewModel.filterEnabled
    }

    func displayRefreshEnded(_ viewModel: MoviesModels.ViewModel.RefreshEnded) {
        refreshControl.endRefreshing()
    }

    func displayScrollToTop(_ viewModel: MoviesModels.ViewModel.ScrollToTop) {
        // `.zero` is not the top: the search bar and safe area push it down by
        // the adjusted inset.
        collectionView.setContentOffset(
            CGPoint(x: 0, y: -collectionView.adjustedContentInset.top),
            animated: false
        )
    }

    func displayMovieSelection(_ viewModel: MoviesModels.ViewModel.MovieSelection) {
        router.routeToDetails()
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
                self?.interactor.toggleWatchlist(.init(index: indexPath.item))
            }
        }
        return cell
    }
}

// MARK: - UISearchResultsUpdating

extension MoviesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        interactor.changeSearchText(.init(text: searchController.searchBar.text ?? ""))
    }
}

// MARK: - UICollectionViewDelegate

extension MoviesViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        interactor.willDisplayItem(.init(index: indexPath.item))
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        interactor.selectMovie(.init(index: indexPath.item))
    }
}
