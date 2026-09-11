import UIKit
import PresentationKit

/// The same grid and the same `MovieCell` as the movies list, without the
/// inputs. It draws what the presenter sends and reports what the reader does.
final class WatchlistViewController: UIViewController {
    let presenter: any WatchlistViewOutput

    private var items: [MovieCell.Model] = []

    private lazy var collectionView = makeCollectionView()
    private var overlay: UIContentUnavailableConfiguration?

    init(presenter: any WatchlistViewOutput) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — VIPER-App builds its UI in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Watchlist"
        view.backgroundColor = .systemBackground
        setUpSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }

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
}

// MARK: - WatchlistView

extension WatchlistViewController: WatchlistView {
    func show(_ movies: [MovieCell.Model]) {
        items = movies
        collectionView.reloadData()
    }

    func updateItem(at index: Int, with model: MovieCell.Model) {
        guard items.indices.contains(index) else { return }
        items[index] = model

        let indexPath = IndexPath(item: index, section: 0)
        guard let cell = collectionView.cellForItem(at: indexPath) as? MovieCell else { return }
        cell.configure(with: model)
    }

    func showLoading() {
        setOverlay(.loading())
    }

    func showEmpty() {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "bookmark")
        configuration.text = "Nothing saved yet"
        configuration.secondaryText = "Bookmark a film and it turns up here."
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
}

// MARK: - UICollectionViewDataSource

extension WatchlistViewController: UICollectionViewDataSource {
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

// MARK: - UICollectionViewDelegate

extension WatchlistViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        presenter.didSelectItem(at: indexPath.item)
    }
}
