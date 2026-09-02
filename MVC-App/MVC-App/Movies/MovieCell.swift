import UIKit
import NukeUI

final class MovieCell: UICollectionViewCell {
    static let reuseIdentifier = "MovieCell"

    struct Model {
        let posterURL: URL?
        let title: String
        let year: String?
        let rating: String?
    }

    private let posterView = LazyImageView()
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
    }

    func configure(with model: Model) {
        posterView.url = model.posterURL
        titleLabel.text = model.title
        subtitleLabel.text = [model.year, model.rating].compactMap { $0 }.joined(separator: " · ")
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

        let stack = UIStackView(arrangedSubviews: [posterView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
            posterView.heightAnchor.constraint(equalTo: posterView.widthAnchor, multiplier: 3.0 / 2.0),
        ])
    }
}
