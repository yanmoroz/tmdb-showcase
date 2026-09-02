import Foundation
import DomainKit

extension AppError {
    /// Whether a cached answer may stand in for this failure.
    ///
    /// Only a transport failure qualifies. `.regionRestricted` has to reach the
    /// user or the VPN prompt turns into silently stale rows, and `.cancelled`
    /// has to stay cancelled or a debounced screen answers a request the reader
    /// already abandoned.
    var allowsCacheFallback: Bool {
        if case .network = self { true } else { false }
    }
}
