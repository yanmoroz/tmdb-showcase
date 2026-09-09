import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import MVP_App

@MainActor
@Suite("MovieDetailsPresenter")
final class MovieDetailsPresenterTests {
    private weak var trackedSUT: MovieDetailsPresenter?
    private var trackedLocation: SourceLocation?

    private let watchlistIDs = FetchWatchlistIDsStub()
    private let addToWatchlist = AddToWatchlistStub()
    private let removeFromWatchlist = RemoveFromWatchlistStub()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The presenter outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    // MARK: - The projection

    @Test("The seed alone already fills the screen")
    func seedFillsTheScreen() {
        let movie = Movie.fixture(id: 1, title: "Dune", overview: "Sand.")
        let (sut, view, _) = makeSUT(movie: movie, details: .failure(.notFound))

        sut.viewDidLoad()

        #expect(view.model?.title == "Dune")
        #expect(view.model?.overview == "Sand.")
    }

    @Test("Loaded details win over the seed")
    func detailsWinOverTheSeed() async throws {
        let movie = Movie.fixture(id: 1, title: "Seeded", overview: "Seeded overview.")
        let details = MovieDetails.fixture(id: 1, title: "Loaded", overview: "Loaded overview.")
        let (sut, view, _) = makeSUT(movie: movie, details: .success(details))

        sut.viewDidLoad()
        try await waitUntil { view.model?.title == "Loaded" }

        #expect(view.model?.overview == "Loaded overview.")
    }

    @Test("An original title identical to the title is not shown")
    func hidesRedundantOriginalTitle() async throws {
        let details = MovieDetails.fixture(id: 1, title: "Dune", originalTitle: "Dune")
        let (sut, view, _) = makeSUT(details: .success(details))

        sut.viewDidLoad()
        try await waitUntil { view.model?.title == "Dune" }

        #expect(view.model?.originalTitle == nil)
    }

    @Test("A distinct original title is shown")
    func showsDistinctOriginalTitle() async throws {
        let details = MovieDetails.fixture(id: 1, title: "The Wages of Fear", originalTitle: "Le salaire de la peur")
        let (sut, view, _) = makeSUT(details: .success(details))

        sut.viewDidLoad()
        try await waitUntil { view.model?.originalTitle != nil }

        #expect(view.model?.originalTitle == "Le salaire de la peur")
    }

    @Test("An empty overview is absent, not blank")
    func emptyOverviewIsAbsent() async throws {
        let details = MovieDetails.fixture(id: 1, tagline: "loaded", overview: "")
        let (sut, view, _) = makeSUT(movie: .fixture(id: 1, overview: ""), details: .success(details))

        sut.viewDidLoad()
        try await waitUntil { view.model?.tagline == "loaded" }

        #expect(view.model?.overview == nil)
    }

    @Test("A card with no release date does not borrow the seed's year")
    func doesNotSpliceTheSeedsYear() async throws {
        let movie = Movie.fixture(id: 1, releaseDate: Date(timeIntervalSince1970: 1_600_000_000))
        // The tagline marks the loaded render: the seed produces metadata of its
        // own, so waiting on that would assert against the wrong instant.
        let details = MovieDetails.fixture(id: 1, tagline: "loaded", releaseDate: nil, runtime: nil, voteCount: 0)
        let (sut, view, _) = makeSUT(movie: movie, details: .success(details))

        sut.viewDidLoad()
        try await waitUntil { view.model?.tagline == "loaded" }

        // Loaded details are the record on screen; the list's date belongs to a
        // different one.
        #expect(view.model?.metadata == nil)
    }

    @Test("Genres are joined, and absent when there are none")
    func joinsGenres() async throws {
        let details = MovieDetails.fixture(id: 1, genres: [.fixture(id: 1, name: "Drama"), .fixture(id: 2, name: "Sci-Fi")])
        let (sut, view, _) = makeSUT(details: .success(details))

        sut.viewDidLoad()
        try await waitUntil { view.model?.genres != nil }

        #expect(view.model?.genres == "Drama, Sci-Fi")
    }

    @Test("Year, runtime and rating are joined for the view")
    func joinsMetadata() async throws {
        let details = MovieDetails.fixture(
            id: 1,
            tagline: "loaded",
            releaseDate: Date(timeIntervalSince1970: 1_600_000_000),
            runtime: 126,
            voteAverage: 8.0,
            voteCount: 100
        )
        let (sut, view, _) = makeSUT(details: .success(details))

        sut.viewDidLoad()
        try await waitUntil { view.model?.tagline == "loaded" }

        #expect(view.model?.metadata == "2020 · 2h 6m · ★ 8.0")
    }

    // MARK: - Loading

    @Test("Details are requested for the seeded movie")
    func requestsTheSeededMovie() async throws {
        let (sut, _, fetchDetails) = makeSUT(movie: .fixture(id: 42), details: .success(.fixture(id: 42)))

        sut.viewDidLoad()
        try await waitUntil { await !fetchDetails.calls.isEmpty }

        #expect(await fetchDetails.calls == [MovieDetailsCall(id: 42)])
    }

    @Test("Nothing ever covers the seeded content", arguments: [AppError.regionRestricted, .network(.offline)])
    func failureNeverReplacesTheCard(error: AppError) async throws {
        let (sut, view, _) = makeSUT(movie: .fixture(id: 1, title: "Dune"), details: .failure(error))

        sut.viewDidLoad()
        try await waitUntil { view.failure != nil }

        #expect(view.model?.title == "Dune")
        #expect(view.failure?.message == error.message)
    }

    @Test("A retryable failure offers Retry, and retrying refetches")
    func retryRefetches() async throws {
        let (sut, view, fetchDetails) = makeSUT(details: .failure(.network(.offline)))

        sut.viewDidLoad()
        try await waitUntil { view.failure?.retry == true }

        await fetchDetails.setResult(.success(.fixture(id: 1, tagline: "Loaded")))
        sut.didTapRetry()

        try await waitUntil { view.model?.tagline == "Loaded" }
        #expect(await fetchDetails.calls.count == 2)
        #expect(view.statusHidden)
    }

    @Test("An unfixable failure offers no Retry")
    func hidesRetryForRegionBlock() async throws {
        let (sut, view, _) = makeSUT(details: .failure(.regionRestricted))

        sut.viewDidLoad()
        try await waitUntil { view.failure != nil }

        #expect(view.failure?.retry == false)
    }

    @Test("The status shows while the request is in flight")
    func showsLoading() {
        let (sut, view, _) = makeSUT(details: .success(.fixture(id: 1)))

        sut.viewDidLoad()

        #expect(view.loadingCount == 1)
    }

    // MARK: - Watchlist

    @Test("The bookmark shows what the store already holds")
    func readsSavedState() async throws {
        await watchlistIDs.setResult(.success([7]))
        let (sut, view, _) = makeSUT(movie: .fixture(id: 7), details: .success(.fixture(id: 7)))

        sut.viewDidLoad()

        try await waitUntil { view.isSaved == true }
    }

    @Test("The bookmark saves the seeded movie")
    func savesTheSeededMovie() async throws {
        let movie = Movie.fixture(id: 7, title: "Dune")
        let (sut, view, _) = makeSUT(movie: movie, details: .failure(.network(.offline)))

        sut.viewDidLoad()
        sut.didTapBookmark()

        #expect(view.isSaved == true)
        try await waitUntil { await self.addToWatchlist.calls == [movie] }
    }

    @Test("Bookmarking a saved film removes it")
    func removesASavedMovie() async throws {
        await watchlistIDs.setResult(.success([7]))
        let (sut, view, _) = makeSUT(movie: .fixture(id: 7), details: .success(.fixture(id: 7)))

        sut.viewDidLoad()
        try await waitUntil { view.isSaved == true }

        sut.didTapBookmark()

        #expect(view.isSaved == false)
        try await waitUntil { await self.removeFromWatchlist.calls == [7] }
    }

    @Test("A failed save puts the bookmark back and says so")
    func rollsBackFailedSave() async throws {
        await addToWatchlist.setResult(.failure(.storage))
        let (sut, view, _) = makeSUT(movie: .fixture(id: 7), details: .success(.fixture(id: 7)))

        sut.viewDidLoad()
        // The initial read reports "not saved" too, so it has to land before the
        // tap or it is indistinguishable from the rollback. Waiting on the value
        // is not enough — viewDidLoad already set it; waiting on the second call
        // is what proves the read finished.
        try await waitUntil { view.savedHistory.count >= 2 }
        sut.didTapBookmark()

        try await waitUntil { !view.toasts.isEmpty }
        #expect(view.savedHistory.suffix(2) == [true, false])
        #expect(view.isSaved == false)
        #expect(view.toasts == [AppError.storage.message])
    }

    // MARK: - Helpers

    private func makeSUT(
        movie: Movie = .fixture(id: 1),
        details: Result<MovieDetails, AppError>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (MovieDetailsPresenter, MovieDetailsViewSpy, FetchMovieDetailsStub) {
        let fetchDetails = FetchMovieDetailsStub(result: details)
        let view = MovieDetailsViewSpy()
        let sut = MovieDetailsPresenter(
            movie: movie,
            fetchDetails: fetchDetails,
            fetchWatchlistIDs: watchlistIDs,
            addToWatchlist: addToWatchlist,
            removeFromWatchlist: removeFromWatchlist,
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        sut.view = view

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, view, fetchDetails)
    }
}

/// Records what the presenter asked the details screen to do.
@MainActor
final class MovieDetailsViewSpy: MovieDetailsView {
    private(set) var model: MovieDetailsModel?
    private(set) var renders = 0
    private(set) var isSaved: Bool?
    /// The sequence, not just the latest value: the initial watchlist read and a
    /// rollback both end at `false`, so only the order tells them apart.
    private(set) var savedHistory: [Bool] = []
    private(set) var loadingCount = 0
    private(set) var failure: (message: String, retry: Bool)?
    private(set) var statusHidden = false
    private(set) var toasts: [String] = []

    func show(_ model: MovieDetailsModel) {
        self.model = model
        renders += 1
    }

    func setSaved(_ isSaved: Bool) {
        self.isSaved = isSaved
        savedHistory.append(isSaved)
    }

    func showLoading() {
        loadingCount += 1
        statusHidden = false
    }

    func showFailure(_ message: String, retry: Bool) {
        failure = (message, retry)
        statusHidden = false
    }

    func hideStatus() {
        statusHidden = true
        failure = nil
    }

    func showToast(_ message: String) {
        toasts.append(message)
    }
}
