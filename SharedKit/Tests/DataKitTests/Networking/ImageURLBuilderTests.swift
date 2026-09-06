import Testing
import Foundation
@testable import DataKit

@Suite("TMDBImageURLBuilder")
struct ImageURLBuilderTests {
    private let builder = TMDBImageURLBuilder(configuration: .test)

    @Test("A relative path becomes a URL of the requested size")
    func buildsPosterURL() {
        #expect(
            builder.posterURL(path: "/poster1.jpg", size: .w342)
                == URL(string: "https://image.tmdb.org/t/p/w342/poster1.jpg")
        )
    }

    @Test("Backdrops are built from their own size set")
    func buildsBackdropURL() {
        #expect(
            builder.backdropURL(path: "/backdrop1.jpg", size: .original)
                == URL(string: "https://image.tmdb.org/t/p/original/backdrop1.jpg")
        )
    }

    @Test("Without a size, the domain protocol yields the shared default")
    func buildsDefaultSizeURLs() {
        #expect(
            builder.posterURL(path: "/poster1.jpg")
                == URL(string: "https://image.tmdb.org/t/p/w342/poster1.jpg")
        )
        #expect(
            builder.backdropURL(path: "/backdrop1.jpg")
                == URL(string: "https://image.tmdb.org/t/p/w780/backdrop1.jpg")
        )
    }

    @Test("A missing path yields no URL", arguments: [nil, ""])
    func returnsNilWithoutPath(path: String?) {
        #expect(builder.posterURL(path: path) == nil)
        #expect(builder.backdropURL(path: path) == nil)
    }
}
