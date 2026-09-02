import Foundation

/// Runs the last piece of work scheduled within a quiet interval.
///
/// The cancellation lives inside `schedule` on purpose: two pending pieces of
/// work, or one firing for input the user has already replaced, stop being
/// possible rather than something every call site has to prevent.
@MainActor
final class Debouncer {
    private let interval: Duration
    private var pending: Task<Void, Never>?

    init(interval: Duration) {
        self.interval = interval
    }

    deinit {
        pending?.cancel()
    }

    func schedule(_ work: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task { [interval] in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            work()
        }
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }
}
