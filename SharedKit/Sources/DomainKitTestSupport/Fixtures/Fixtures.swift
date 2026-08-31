import Foundation

public enum Fixtures {
    /// Fixture reference date: 2001-09-09.
    ///
    /// Fixed rather than `Date()` so results do not depend on when the test runs.
    public static let referenceDate = Date(timeIntervalSince1970: 1_000_000_000)
}
