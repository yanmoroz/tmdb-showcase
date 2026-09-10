import Testing
import Foundation
import UIKit

/// The interactor keeps its `Task` private, so waiting means polling a spy.
func waitUntil(
    timeout: Duration = .seconds(2),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () async -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition was not met within \(timeout)", sourceLocation: sourceLocation)
}

/// Hands the main actor to whatever may have been enqueued.
///
/// Tasks inherit `MainActor` from the caller, so they cannot start while a
/// `@MainActor` test body runs. Yielding gives them that chance without leaning
/// on wall-clock time: a fixed sleep would let a slow machine hide a request
/// that does get sent, just after the window closes.
@MainActor
func drainPendingWork(iterations: Int = 10) async {
    for _ in 0..<iterations {
        await Task.yield()
    }
}

/// The controller builds its hierarchy in code and exposes none of it, so tests
/// reach a view by walking down from the root.
extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let found = subview.firstSubview(of: type) { return found }
        }
        return nil
    }
}
