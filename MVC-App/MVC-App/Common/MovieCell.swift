import UIKit
import NukeUI

final class MovieCell: UICollectionViewCell {
    static let reuseIdentifier = "MovieCell"

    struct Model {
        let posterURL: URL?
        let title: String
        let year: String?
        let rating: String?
        let isSaved: Bool
    }

    /// Cleared on reuse: a stale closure would toggle whichever film the cell
    /// used to hold.
    var onToggleWatchlist: (() -> Void)?

    private let posterContainer = UIView()
    private let posterView = LazyImageView()
    private lazy var bookmarkButton = makeBookmarkButton()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVC-App builds its UI in code")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        posterView.url = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
        onToggleWatchlist = nil
    }

    func configure(with model: Model) {
        posterView.url = model.posterURL
        titleLabel.text = model.title
        subtitleLabel.text = [model.year, model.rating].compactMap { $0 }.joined(separator: " · ")
        apply(isSaved: model.isSaved)
    }

    private func apply(isSaved: Bool) {
        bookmarkButton.configuration?.image = UIImage(
            systemName: isSaved ? "bookmark.fill" : "bookmark"
        )
        bookmarkButton.accessibilityLabel = isSaved ? "Remove from watchlist" : "Add to watchlist"
    }

    private func makeBookmarkButton() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "bookmark")
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        configuration.baseForegroundColor = .white
        // The glyph sits on artwork of any colour, so it carries its own ground.
        configuration.background.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        configuration.background.cornerRadius = 12
        configuration.buttonSize = .mini

        return HitTargetButton(
            configuration: configuration,
            primaryAction: UIAction { [weak self] _ in self?.onToggleWatchlist?() }
        )
    }

    private func setUp() {
        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.layer.cornerRadius = 8
        posterView.layer.cornerCurve = .continuous
        posterView.backgroundColor = .secondarySystemFill

        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.font = .preferredFont(forTextStyle: .caption2)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.adjustsFontForContentSizeCategory = true

        for view in [posterView, bookmarkButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            posterContainer.addSubview(view)
        }

        let stack = UIStackView(arrangedSubviews: [posterContainer, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),

            posterView.topAnchor.constraint(equalTo: posterContainer.topAnchor),
            posterView.leadingAnchor.constraint(equalTo: posterContainer.leadingAnchor),
            posterView.trailingAnchor.constraint(equalTo: posterContainer.trailingAnchor),
            posterView.bottomAnchor.constraint(equalTo: posterContainer.bottomAnchor),
            posterView.heightAnchor.constraint(equalTo: posterView.widthAnchor, multiplier: 3.0 / 2.0),

            bookmarkButton.topAnchor.constraint(equalTo: posterContainer.topAnchor, constant: 4),
            bookmarkButton.trailingAnchor.constraint(equalTo: posterContainer.trailingAnchor, constant: -4),
        ])
    }
}

/// The chip stays small so it does not swallow the poster, but a ~28pt target in
/// a three-up grid is below the 44pt guideline — and every pixel it misses is a
/// tap that pushes the details screen instead.
private final class HitTargetButton: UIButton {
    private static let outset: CGFloat = 8

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -Self.outset, dy: -Self.outset).contains(point)
    }
}
