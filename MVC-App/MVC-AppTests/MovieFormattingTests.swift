import Testing
import Foundation
@testable import MVC_App

@MainActor
@Suite("MovieFormatting")
struct MovieFormattingTests {
    @Test("A release date becomes its year")
    func formatsYear() {
        #expect(MovieFormatting.year(Date(timeIntervalSince1970: 1_700_000_000)) == "2023")
    }

    /// `TMDBDate` parses release dates in GMT, so a 1 January release rendered
    /// in the device's zone reads as the year before anywhere west of it.
    @Test("The year is read in GMT, not the device's zone")
    func readsYearInGMT() throws {
        // Two instants straddling midnight GMT. Whichever way this machine is
        // offset, one of them disagrees with the local answer — a single date
        // would only catch the bug on machines west of GMT.
        let lastMomentOf2020 = Date(timeIntervalSince1970: 1_609_459_140)
        let firstMomentOf2021 = Date(timeIntervalSince1970: 1_609_459_200)

        #expect(MovieFormatting.year(lastMomentOf2020) == "2020")
        #expect(MovieFormatting.year(firstMomentOf2021) == "2021")

        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        #expect(MovieFormatting.year(firstMomentOf2021, in: newYork) == "2020")
    }

    @Test("No release date, no year")
    func omitsMissingYear() {
        #expect(MovieFormatting.year(nil) == nil)
    }

    @Test("A rated film shows its average")
    func formatsRating() {
        #expect(MovieFormatting.rating(average: 7.46, count: 120) == "★ 7.5")
    }

    /// TMDB reports 0.0 for an unrated film, and "★ 0.0" reads as a bad score
    /// rather than a missing one.
    @Test("An unvoted film shows no rating")
    func omitsRatingWithoutVotes() {
        #expect(MovieFormatting.rating(average: 0, count: 0) == nil)
    }

    @Test("Runtime reads in hours and minutes", arguments: [
        (126, "2h 6m"),
        (48, "48m"),
        (120, "2h"),
        (59, "59m"),
        (60, "1h"),
    ])
    func formatsRuntime(minutes: Int, expected: String) {
        #expect(MovieFormatting.runtime(minutes: minutes) == expected)
    }

    @Test("An absent or zero runtime shows nothing", arguments: [nil, 0])
    func omitsMissingRuntime(minutes: Int?) {
        #expect(MovieFormatting.runtime(minutes: minutes) == nil)
    }
}
