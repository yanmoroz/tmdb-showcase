import Foundation

enum TMDBDate {
    /// `ISO8601FormatStyle` rather than `DateFormatter`: the latter is not
    /// `Sendable` and cannot be held in a `static let` under Swift 6.
    private static let style = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()

    /// Parses `"2021-10-22"`. TMDB sends `""` when it has no date.
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return try? style.parse(raw)
    }
}
