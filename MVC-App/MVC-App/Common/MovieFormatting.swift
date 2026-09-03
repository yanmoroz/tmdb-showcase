import Foundation

/// Presentation rules shared by the grid and the details screen.
///
/// Flat values in, strings out — nothing here knows about a controller or a
/// domain entity, which is what keeps `Common/` extractable later.
enum MovieFormatting {
    /// Rendered in GMT because `TMDBDate` parses in GMT: in any zone west of it
    /// a 1 January release would otherwise read as the year before. The calendar
    /// is pinned for the same reason the locale used to be — under a Buddhist or
    /// Japanese calendar the year is not the one TMDB meant.
    static func year(_ releaseDate: Date?, in timeZone: TimeZone = .gmt) -> String? {
        guard let releaseDate else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return String(calendar.component(.year, from: releaseDate))
    }

    /// `nil` when nobody has voted: TMDB reports `0.0` for an unrated film, and
    /// "★ 0.0" reads as a bad score rather than a missing one.
    static func rating(average: Double, count: Int) -> String? {
        count > 0 ? String(format: "★ %.1f", average) : nil
    }

    /// "2h 6m", "48m", "2h" — assembled by hand rather than with
    /// `DateComponentsFormatter`, which localises its units. The app is
    /// deliberately English-only, so a localised runtime beside English labels
    /// would be the one inconsistent string on the screen.
    static func runtime(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }

        let (hours, remainder) = minutes.quotientAndRemainder(dividingBy: 60)
        return switch (hours, remainder) {
        case (0, let minutes): "\(minutes)m"
        case (let hours, 0): "\(hours)h"
        case (let hours, let minutes): "\(hours)h \(minutes)m"
        }
    }
}
