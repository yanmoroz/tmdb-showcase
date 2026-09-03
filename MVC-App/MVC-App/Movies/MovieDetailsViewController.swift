import UIKit
import NukeUI
import DomainKit

/// Seeded with the `Movie` the list already holds, so the screen is never blank:
/// title, artwork, year, rating and overview are on screen before `/movie/{id}`
/// is asked, and the rest appears when it answers.
final class MovieDetailsViewController: UIViewController {
    /// Everything the screen draws, flat and already formatted.
    ///
    /// A pure projection of the seed plus whatever has loaded. The rules about
    /// which fields count as absent live here, where they can be tested without
    /// standing a view up.
    struct Model: Equatable {
        let title: String
        let posterURL: URL?
        let backdropURL: URL?
        let year: String?
        let rating: String?
        let originalTitle: String?
        let tagline: String?
        let genres: String?
        let runtime: String?
        let overview: String?
        let homepage: URL?
    }

    /// Only so a test can address one label among several; `firstSubview(of:)`
    /// alone returns whichever comes first.
    enum Identifier {
        static let title = "movieDetails.title"
        static let overview = "movieDetails.overview"
    }

    private enum Details {
        case idle
        case loading(Task<Void, Never>)
        case loaded(MovieDetails)
        case failed(AppError)
    }

    private let movie: Movie
    private let fetchDetails: any FetchMovieDetailsUseCase
    private let imageURLBuilder: any MovieImageURLBuilder

    private var details: Details = .idle {
        didSet { render() }
    }

    private let backdropView = LazyImageView()
    private let posterView = LazyImageView()
    private let titleLabel = UILabel()
    private let originalTitleLabel = UILabel()
    private let metadataLabel = UILabel()
    private let genresLabel = UILabel()
    private let taglineLabel = UILabel()
    private let overviewLabel = UILabel()
    private lazy var homepageButton = makeHomepageButton()
    private lazy var statusView = UIContentUnavailableView(
        configuration: UIContentUnavailableConfiguration.loading()
    )
    private lazy var scrollView = UIScrollView()

    init(
        movie: Movie,
        fetchDetails: any FetchMovieDetailsUseCase,
        imageURLBuilder: any MovieImageURLBuilder
    ) {
        self.movie = movie
        self.fetchDetails = fetchDetails
        self.imageURLBuilder = imageURLBuilder
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVC-App builds its UI in code")
    }

    deinit {
        if case .loading(let task) = details {
            task.cancel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = movie.title
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        setUpSubviews()
        render()
        load()
    }

    // MARK: - Loading

    private func load() {
        if case .loading(let task) = details {
            task.cancel()
        }

        details = .loading(
            Task { [weak self] in
                guard let self else { return }

                let outcome: Result<MovieDetails, AppError>
                do {
                    outcome = .success(try await fetchDetails(id: movie.id))
                } catch let error as AppError {
                    outcome = .failure(error)
                } catch {
                    outcome = .failure(.unknown)
                }

                guard !Task.isCancelled else { return }

                switch outcome {
                case .success(let details): self.details = .loaded(details)
                case .failure(let error): self.details = .failed(error)
                }
            }
        )
    }

    /// Internal so a test can retry without reaching into the status view's
    /// button, the same reason `MoviesViewController.applyFilter` is internal.
    func reload() {
        load()
    }

    // MARK: - Rendering

    private var loadedDetails: MovieDetails? {
        if case .loaded(let details) = details { details } else { nil }
    }

    private func render() {
        apply(Model(movie: movie, details: loadedDetails, imageURLBuilder: imageURLBuilder))

        // Additive, never a screen-wide overlay: the seeded content stays on
        // screen while the rest loads or fails.
        switch details {
        case .idle, .loaded:
            statusView.isHidden = true
        case .loading:
            statusView.configuration = UIContentUnavailableConfiguration.loading()
            statusView.isHidden = false
        case .failed(let error):
            statusView.configuration = failureConfiguration(error)
            statusView.isHidden = false
        }
    }

    private func apply(_ model: Model) {
        backdropView.url = model.backdropURL
        backdropView.isHidden = model.backdropURL == nil
        posterView.url = model.posterURL
        posterView.isHidden = model.posterURL == nil

        titleLabel.accessibilityIdentifier = Identifier.title
        overviewLabel.accessibilityIdentifier = Identifier.overview

        titleLabel.text = model.title
        set(originalTitleLabel, model.originalTitle)
        set(metadataLabel, [model.year, model.runtime, model.rating].compactMap { $0 }
            .joined(separator: " · ").nilWhenEmpty)
        set(genresLabel, model.genres)
        set(taglineLabel, model.tagline)
        set(overviewLabel, model.overview)

        homepageButton.isHidden = model.homepage == nil
    }

    private func set(_ label: UILabel, _ text: String?) {
        label.text = text
        label.isHidden = text == nil
    }

    private func failureConfiguration(_ error: AppError) -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "Couldn't load the details"
        configuration.secondaryText = error.message

        // Same reasoning as the movies screen: cancellation is not retryable, but
        // retrying is the only move left when nothing arrived.
        if error.isRetryable || error == .cancelled {
            var button = UIButton.Configuration.borderless()
            button.title = "Retry"
            configuration.button = button
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                self?.reload()
            }
        }
        return configuration
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
            posterView.widthAnchor.constraint(equalToConstant: 100),
            posterView.heightAnchor.constraint(equalTo: posterView.widthAnchor, multiplier: 3.0 / 2.0),
        ])
    }

    private func makeContentStack() -> UIStackView {
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
            backdropView, header, taglineLabel, overviewLabel, homepageButton, statusView,
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

    private func makeHomepageButton() -> UIButton {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = "Open homepage"
        configuration.image = UIImage(systemName: "safari")
        configuration.imagePadding = 6

        return UIButton(
            configuration: configuration,
            primaryAction: UIAction { [weak self] _ in
                guard let url = self?.loadedDetails?.homepage else { return }
                UIApplication.shared.open(url)
            }
        )
    }
}

private extension String {
    var nilWhenEmpty: String? { isEmpty ? nil : self }
}

extension MovieDetailsViewController.Model {
    /// Loaded details win, the seed fills the gaps — so nothing already on
    /// screen can vanish when the request lands, and nothing waits for it that
    /// the list already knew.
    init(movie: Movie, details: MovieDetails?, imageURLBuilder: any MovieImageURLBuilder) {
        let card = details.map { Card($0) } ?? Card(movie)
        let genreNames = (details?.genres ?? []).map(\.name)

        self.init(
            title: card.title,
            posterURL: imageURLBuilder.posterURL(path: card.posterPath),
            backdropURL: imageURLBuilder.backdropURL(path: card.backdropPath),
            year: MovieFormatting.year(card.releaseDate),
            rating: MovieFormatting.rating(average: card.voteAverage, count: card.voteCount),
            // TMDB repeats `title` when a film has no distinct original title,
            // so showing it unconditionally would print the same line twice.
            originalTitle: details.flatMap { $0.originalTitle == $0.title ? nil : $0.originalTitle },
            tagline: details?.tagline,
            genres: genreNames.isEmpty ? nil : genreNames.joined(separator: ", "),
            runtime: MovieFormatting.runtime(minutes: details?.runtime),
            // Not optional in the domain, but TMDB sends "" for a missing one.
            overview: card.overview.isEmpty ? nil : card.overview,
            homepage: details?.homepage.flatMap(Self.openable)
        )
    }

    /// TMDB stores whatever the studio typed. A link we cannot open is not a link.
    private static func openable(_ url: URL) -> URL? {
        switch url.scheme?.lowercased() {
        case "http", "https": url
        default: nil
        }
    }
}

/// The fields `Movie` and `MovieDetails` both carry, taken from one side or the
/// other and never spliced.
///
/// `details?.releaseDate ?? movie.releaseDate` reads as "details wins" but means
/// "details wins unless it says no" — which puts the list's date under the
/// card's title, a record nobody published.
private struct Card {
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: Date?
    let voteAverage: Double
    let voteCount: Int

    init(_ movie: Movie) {
        title = movie.title
        overview = movie.overview
        posterPath = movie.posterPath
        backdropPath = movie.backdropPath
        releaseDate = movie.releaseDate
        voteAverage = movie.voteAverage
        voteCount = movie.voteCount
    }

    init(_ details: MovieDetails) {
        title = details.title
        overview = details.overview
        posterPath = details.posterPath
        backdropPath = details.backdropPath
        releaseDate = details.releaseDate
        voteAverage = details.voteAverage
        voteCount = details.voteCount
    }
}
