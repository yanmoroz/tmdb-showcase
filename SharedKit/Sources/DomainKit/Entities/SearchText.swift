import Foundation

/// A search query guaranteed not to be blank.
///
/// TMDB requires a non-empty `query`, so `MoviesQuery.search` cannot be built
/// from whitespace.
public struct SearchText: Hashable, Sendable {
    /// The input trimmed of surrounding whitespace. Never empty.
    public let rawValue: String

    /// `nil` when nothing is left after trimming.
    public init?(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.rawValue = trimmed
    }
}
