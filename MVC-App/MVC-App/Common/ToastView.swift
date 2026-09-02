import UIKit

/// A transient message pinned above the safe area.
///
/// Used for errors that must not replace already-loaded content — the geo-block
/// notice, for one: the list stays usable while the toast explains the VPN.
final class ToastView: UIView {
    private static let visibleDuration: TimeInterval = 4

    private let label = UILabel()
    private var dismissTask: Task<Void, Never>?

    init(message: String) {
        super.init(frame: .zero)
        setUp(message: message)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable — MVC-App builds its UI in code")
    }

    deinit {
        dismissTask?.cancel()
    }

    static func show(_ message: String, in container: UIView) {
        container.subviews.compactMap { $0 as? ToastView }.forEach { $0.dismiss() }

        let toast = ToastView(message: message)
        toast.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.leadingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            toast.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])

        toast.alpha = 0
        UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
        toast.scheduleDismiss()
    }

    private func setUp(message: String) {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        label.text = message
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    private func scheduleDismiss() {
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.visibleDuration))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        UIView.animate(withDuration: 0.2) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}
