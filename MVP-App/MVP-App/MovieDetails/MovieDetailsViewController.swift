import UIKit
import NukeUI
import YouTubeiOSPlayerHelper
import PresentationKit

/// Draws the card the presenter projects. It holds no `MovieDetails`, no `Task`
/// and no idea whether anything is still loading.
final class MovieDetailsViewController: UIViewController {
    /// Only so a test can address one label among several; `firstSubview(of:)`
    /// alone returns whichever comes first.
    enum Identifier {
        static let title = "movieDetails.title"
        static let overview = "movieDetails.overview"
    }

    private let presenter: MovieDetailsPresenter

    private lazy var bookmarkItem = UIBarButtonItem(
        primaryAction: UIAction { [weak self] _ in self?.presenter.didTapBookmark() }
    )

    private let backdropView = LazyImageView()
    private let posterView = LazyImageView()
    private let titleLabel = UILabel()
    private let originalTitleLabel = UILabel()
    private let metadataLabel = UILabel()
    private let genresLabel = UILabel()
    private let taglineLabel = UILabel()
    private let overviewLabel = UILabel()
    private let trailerView = YTPlayerView()
    /// The player reloads only when the id changes: re-rendering on any other
    /// state change would restart a video the reader is already watching.
    private var loadedTrailerKey: String?
    private lazy var statusView = UIContentUnavailableView(
        configuration: UIContentUnavailableConfiguration.loading()
    )
    private lazy var scrollView = UIScrollView()

    init(presenter: MovieDetailsPresenter) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVP-App builds its UI in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = presenter.title
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = bookmarkItem
        setUpSubviews()
        presenter.viewDidLoad()
    }

    // MARK: - Layout

    private func setUpSubviews() {
        let stack = makeContentStack()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            backdropView.heightAnchor.constraint(equalTo: backdropView.widthAnchor, multiplier: 9.0 / 16.0),
            trailerView.heightAnchor.constraint(equalTo: trailerView.widthAnchor, multiplier: 9.0 / 16.0),
            posterView.widthAnchor.constraint(equalToConstant: 100),
            posterView.heightAnchor.constraint(equalTo: posterView.widthAnchor, multiplier: 3.0 / 2.0),
        ])
    }

    private func makeContentStack() -> UIStackView {
        trailerView.backgroundColor = .systemBackground

        for view in [backdropView, posterView] {
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            view.layer.cornerRadius = 8
            view.layer.cornerCurve = .continuous
            view.backgroundColor = .secondarySystemFill
        }

        style(titleLabel, .title2, .label, weight: .semibold)
        style(originalTitleLabel, .subheadline, .secondaryLabel)
        style(metadataLabel, .footnote, .secondaryLabel)
        style(genresLabel, .footnote, .secondaryLabel)
        style(taglineLabel, .callout, .secondaryLabel)
        style(overviewLabel, .body, .label)

        titleLabel.accessibilityIdentifier = Identifier.title
        overviewLabel.accessibilityIdentifier = Identifier.overview

        let summary = UIStackView(arrangedSubviews: [
            titleLabel, originalTitleLabel, metadataLabel, genresLabel,
        ])
        summary.axis = .vertical
        summary.spacing = 4

        let header = UIStackView(arrangedSubviews: [posterView, summary])
        header.axis = .horizontal
        header.spacing = 12
        header.alignment = .top

        let stack = UIStackView(arrangedSubviews: [
            backdropView, header, taglineLabel, overviewLabel, trailerView, statusView,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(8, after: header)
        return stack
    }

    private func style(
        _ label: UILabel,
        _ style: UIFont.TextStyle,
        _ color: UIColor,
        weight: UIFont.Weight? = nil
    ) {
        let font = UIFont.preferredFont(forTextStyle: style)
        label.font = weight.map { UIFont.systemFont(ofSize: font.pointSize, weight: $0) } ?? font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }

    private func set(_ label: UILabel, _ text: String?) {
        label.text = text
        label.isHidden = text == nil
    }
}

// MARK: - MovieDetailsView

extension MovieDetailsViewController: MovieDetailsView {
    func show(_ model: MovieDetailsModel) {
        backdropView.url = model.backdropURL
        backdropView.isHidden = model.backdropURL == nil
        posterView.url = model.posterURL
        posterView.isHidden = model.posterURL == nil

        titleLabel.text = model.title
        set(originalTitleLabel, model.originalTitle)
        set(metadataLabel, model.metadata)
        set(genresLabel, model.genres)
        set(taglineLabel, model.tagline)
        set(overviewLabel, model.overview)

        trailerView.isHidden = model.trailerKey == nil
        if let trailerKey = model.trailerKey, trailerKey != loadedTrailerKey {
            loadedTrailerKey = trailerKey
            trailerView.delegate = self
            trailerView.load(withVideoId: trailerKey)
        }
    }

    func setSaved(_ isSaved: Bool) {
        bookmarkItem.image = UIImage(systemName: isSaved ? "bookmark.fill" : "bookmark")
        bookmarkItem.accessibilityLabel = isSaved ? "Remove from watchlist" : "Add to watchlist"
    }

    func showLoading() {
        statusView.configuration = UIContentUnavailableConfiguration.loading()
        statusView.isHidden = false
    }

    func showFailure(_ message: String, retry: Bool) {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "Couldn't load the details"
        configuration.secondaryText = message

        if retry {
            var button = UIButton.Configuration.borderless()
            button.title = "Retry"
            configuration.button = button
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                self?.presenter.didTapRetry()
            }
        }
        statusView.configuration = configuration
        statusView.isHidden = false
    }

    func hideStatus() {
        statusView.isHidden = true
    }

    func showToast(_ message: String) {
        ToastView.show(message, in: view)
    }
}

// MARK: - YTPlayerViewDelegate

extension MovieDetailsViewController: YTPlayerViewDelegate {
    /// Read once, when the player builds its web view — which is why the
    /// delegate is assigned before `load(withVideoId:)` rather than after.
    ///
    /// This covers the web view and the player's own loading view. It does not
    /// reach the page: the bundled `YTPlayerView-iframe-player.html` hard-codes
    /// `background-color:#000000` on `html` and `body`, and the library gives no
    /// hook to restyle it. That black is only visible if the iframe fails to
    /// cover the view, which the 16:9 constraint prevents.
    func playerViewPreferredWebViewBackgroundColor(_ playerView: YTPlayerView) -> UIColor {
        .systemBackground
    }
}
