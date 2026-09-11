import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import VIPER_App

private typealias SavedChange = MovieDetailsInteractorSpy.SavedChange

/// Which fields count as absent is `MovieDetailsModelTests`, in PresentationKit.
/// These check what the presenter feeds the projection, and when it redraws.
@MainActor
@Suite("MovieDetailsPresenter")
final class MovieDetailsPresenterTests {
    private weak var trackedSUT: MovieDetailsPresenter?
    private var trackedLocation: SourceLocation?

    private let view = MovieDetailsViewSpy()
    private let interactor = MovieDetailsInteractorSpy()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The presenter outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    // MARK: - The card

    @Test("The seed alone already fills the screen")
    func seedFillsTheScreen() {
        let sut = makeSUT(movie: .fixture(id: 1, title: "Dune", overview: "Sand."))

        sut.viewDidLoad()

        #expect(view.model?.title == "Dune")
        #expect(view.model?.overview == "Sand.")
    }

    @Test("Loaded details win over the seed")
    func detailsWinOverTheSeed() {
        let sut = makeSUT(movie: .fixture(id: 1, title: "Seeded", overview: "Seeded overview."))

        sut.viewDidLoad()
        sut.didLoadDetails(.fixture(id: 1, title: "Loaded", overview: "Loaded overview."))

        #expect(view.model?.title == "Loaded")
        #expect(view.model?.overview == "Loaded overview.")
    }

    @Test("Year, runtime and rating are joined for the view")
    func joinsMetadata() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoadDetails(
            .fixture(
                id: 1,
                releaseDate: Date(timeIntervalSince1970: 1_600_000_000),
                runtime: 126,
                voteAverage: 8.0,
                voteCount: 100
            )
        )

        #expect(view.model?.metadata == "2020 · 2h 6m · ★ 8.0")
    }

    @Test("The screen is named after the seed")
    func titleIsTheSeeds() {
        let sut = makeSUT(movie: .fixture(id: 1, title: "Dune"))

        #expect(sut.title == "Dune")
    }

    // MARK: - Loading

    @Test("Details are requested for the seeded movie")
    func requestsTheSeededMovie() {
        let sut = makeSUT(movie: .fixture(id: 42))

        sut.viewDidLoad()

        #expect(interactor.detailLoads == [42])
    }

    @Test("The status shows while the request is in flight")
    func showsLoading() {
        let sut = makeSUT()

        sut.viewDidLoad()

        #expect(view.status == .loading)
    }

    @Test("The status clears when the details land")
    func hidesTheStatusOnLoad() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoadDetails(.fixture(id: 1))

        #expect(view.status == .hidden)
    }

    @Test("Nothing ever covers the seeded content", arguments: [AppError.regionRestricted, .network(.offline)])
    func failureNeverReplacesTheCard(error: AppError) {
        let sut = makeSUT(movie: .fixture(id: 1, title: "Dune"))

        sut.viewDidLoad()
        sut.didFailToLoadDetails(with: error)

        #expect(view.model?.title == "Dune")
        #expect(view.status == .failure(error.message, retry: error.isRetryable))
    }

    @Test("Cancellation still offers a way out")
    func offersRetryAfterCancellation() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didFailToLoadDetails(with: .cancelled)

        #expect(view.status == .failure(AppError.cancelled.message, retry: true))
    }

    @Test("Retrying asks again and shows the status again")
    func retryRefetches() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didFailToLoadDetails(with: .network(.offline))
        sut.didTapRetry()

        #expect(interactor.detailLoads == [1, 1])
        #expect(view.status == .loading)
    }

    // MARK: - Watchlist

    @Test("The bookmark shows what the store already holds")
    func readsSavedState() {
        let sut = makeSUT(movie: .fixture(id: 7))

        sut.viewDidLoad()
        sut.didLoadSavedIDs([7])

        #expect(interactor.savedIDsLoadCount == 1)
        #expect(view.isSaved == true)
    }

    @Test("Another film being saved leaves this bookmark empty")
    func ignoresOtherSavedFilms() {
        let sut = makeSUT(movie: .fixture(id: 7))

        sut.viewDidLoad()
        sut.didLoadSavedIDs([8])

        #expect(view.isSaved == false)
    }

    @Test("The bookmark marks the seeded movie at once and asks to save it")
    func savesTheSeededMovie() {
        let movie = Movie.fixture(id: 7, title: "Dune")
        let sut = makeSUT(movie: movie)

        sut.viewDidLoad()
        sut.didTapBookmark()

        #expect(view.isSaved == true)
        #expect(interactor.savedChanges == [SavedChange(isSaved: true, movie: movie)])
    }

    @Test("Bookmarking a saved film asks to remove it")
    func removesASavedMovie() {
        let movie = Movie.fixture(id: 7)
        let sut = makeSUT(movie: movie)

        sut.viewDidLoad()
        sut.didLoadSavedIDs([7])
        sut.didTapBookmark()

        #expect(view.isSaved == false)
        #expect(interactor.savedChanges == [SavedChange(isSaved: false, movie: movie)])
    }

    @Test("A failed save puts the bookmark back and says so")
    func rollsBackFailedSave() {
        let sut = makeSUT(movie: .fixture(id: 7))

        sut.viewDidLoad()
        sut.didTapBookmark()
        sut.didFailToSetSaved(true, for: 7, with: .storage)

        #expect(view.isSaved == false)
        #expect(view.toasts == [AppError.storage.message])
    }

    // MARK: - Helpers

    private func makeSUT(
        movie: Movie = .fixture(id: 1),
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> MovieDetailsPresenter {
        let sut = MovieDetailsPresenter(
            movie: movie,
            interactor: interactor,
            imageURLBuilder: MovieImageURLBuilderStub()
        )
        sut.view = view

        trackedSUT = sut
        trackedLocation = sourceLocation
        return sut
    }
}

/// Records what the presenter asked the details screen to do.
@MainActor
final class MovieDetailsViewSpy: MovieDetailsView {
    enum Status: Equatable {
        case hidden
        case loading
        case failure(String, retry: Bool)
    }

    private(set) var model: MovieDetailsModel?
    private(set) var isSaved: Bool?
    private(set) var status: Status = .hidden
    private(set) var toasts: [String] = []

    func show(_ model: MovieDetailsModel) {
        self.model = model
    }

    func setSaved(_ isSaved: Bool) {
        self.isSaved = isSaved
    }

    func showLoading() { status = .loading }
    func showFailure(_ message: String, retry: Bool) { status = .failure(message, retry: retry) }
    func hideStatus() { status = .hidden }

    func showToast(_ message: String) {
        toasts.append(message)
    }
}

/// Records what the presenter asked for and answers nothing: the tests play the
/// interactor's output themselves.
@MainActor
final class MovieDetailsInteractorSpy: MovieDetailsInteractorInput {
    struct SavedChange: Equatable {
        let isSaved: Bool
        let movie: Movie
    }

    private(set) var detailLoads: [Movie.ID] = []
    private(set) var savedIDsLoadCount = 0
    private(set) var savedChanges: [SavedChange] = []

    func loadDetails(for id: Movie.ID) {
        detailLoads.append(id)
    }

    func loadSavedIDs() {
        savedIDsLoadCount += 1
    }

    func setSaved(_ isSaved: Bool, for movie: Movie) {
        savedChanges.append(SavedChange(isSaved: isSaved, movie: movie))
    }
}
