import Testing
import Foundation
import UIKit

/// Hands the main actor to whatever a controller may have enqueued.
///
/// Load tasks inherit `MainActor` from the caller, so they cannot start while a
/// `@MainActor` test body runs. Yielding gives them that chance without leaning
/// on wall-clock time: a fixed sleep would let a slow machine hide a request
/// that does get sent, just after the window closes.
@MainActor
func drainPendingWork(iterations: Int = 10) async {
    for _ in 0..<iterations {
        await Task.yield()
    }
}

/// Controllers keep their `Task` private, so waiting means polling state.
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
    Issue.record("Условие не выполнилось за \(timeout)", sourceLocation: sourceLocation)
}

/// Captures a callback result without the closure retaining the test suite.
@MainActor
final class Box<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}

/// Controllers build their hierarchy in code and expose none of it, so tests
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
