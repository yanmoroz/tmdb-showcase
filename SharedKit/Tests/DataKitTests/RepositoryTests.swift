import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
@testable import DataKit

@Suite("TMDBMoviesRepository")
struct MoviesRepositoryTests {
    private func makeRepository(_ response: StubResponse) -> (TMDBMoviesRepository, StubSession) {
        let stub = StubURLProtocol.makeSession(response)
        return (TMDBMoviesRepository(configuration: .test, session: stub.session), stub)
    }

    @Test("A page travels the whole way from JSON to the domain")
    func loadsPage() async throws {
        let (repository, _) = makeRepository(.json(try TestFixtures.data("popular_page1")))

        let page = try await repository.movies(query: .popular, page: 1)

        #expect(page.items.count == 2)
        #expect(page.items.first?.title == "Dune: Part Two")
        #expect(page.totalPages == 500)
    }

    @Test("The requested URL is built from the domain query")
    func buildsRequestURL() async throws {
        let (repository, stub) = makeRepository(.json(try TestFixtures.data("popular_page1")))

        _ = try await repository.movies(query: .trending(.week), page: 3)

        let request = try #require(stub.lastRequest)
        #expect(request.url?.path() == "/3/trending/movie/week")
        #expect(request.url?.query()?.contains("page=3") == true)
    }

    @Test("The authorization header reaches the transport")
    func sendsAuthorizationHeader() async throws {
        let (repository, stub) = makeRepository(.json(try TestFixtures.data("popular_page1")))

        _ = try await repository.movies(query: .popular, page: 1)

        let request = try #require(stub.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    @Test("Movie details are requested by identifier")
    func loadsDetails() async throws {
        let (repository, stub) = makeRepository(.json(try TestFixtures.data("movie_details")))

        let details = try await repository.movieDetails(id: 550)

        #expect(details.title == "Fight Club")
        #expect(stub.lastRequest?.url?.path() == "/3/movie/550")
    }

    @Test("A missing movie yields notFound")
    func mapsNotFound() async {
        let (repository, _) = makeRepository(.status(404))

        await #expect(throws: AppError.notFound) {
            try await repository.movieDetails(id: 1)
        }
    }

    @Test("A region block yields regionRestricted")
    func mapsRegionRestricted() async {
        let (repository, _) = makeRepository(.status(403))

        await #expect(throws: AppError.regionRestricted) {
            try await repository.movies(query: .popular, page: 1)
        }
    }

    @Test("A dropped connection yields network(.offline)")
    func mapsTransportFailure() async {
        let (repository, _) = makeRepository(.transport(.notConnectedToInternet))

        await #expect(throws: AppError.network(.offline)) {
            try await repository.movies(query: .popular, page: 1)
        }
    }

    @Test("Malformed JSON yields decoding, not unknown")
    func mapsDecodingFailure() async {
        let (repository, _) = makeRepository(.json(Data(#"{"unexpected": true}"#.utf8)))

        await #expect(throws: AppError.decoding) {
            try await repository.movies(query: .popular, page: 1)
        }
    }
}

@Suite("TMDBGenresRepository")
struct GenresRepositoryTests {
    @Test("The genre catalogue travels through to the domain")
    func loadsGenres() async throws {
        let stub = StubURLProtocol.makeSession(.json(try TestFixtures.data("genres")))
        let repository = TMDBGenresRepository(configuration: .test, session: stub.session)

        let genres = try await repository.genres()

        #expect(genres == Genre.fixtures)
        #expect(stub.lastRequest?.url?.path() == "/3/genre/movie/list")
    }
}

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

    @Test("A missing path yields no URL", arguments: [nil, ""])
    func returnsNilWithoutPath(path: String?) {
        #expect(builder.posterURL(path: path) == nil)
        #expect(builder.backdropURL(path: path) == nil)
    }
}
