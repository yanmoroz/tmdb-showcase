import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import MVP_App

@MainActor
@Suite("MoviesFilterPresenter")
final class MoviesFilterPresenterTests {
    private weak var trackedSUT: MoviesFilterPresenter?
    private var trackedLocation: SourceLocation?

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The presenter outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    @Test("The catalogue loads and puts an \"All\" row above the genres")
    func showsAllAboveTheGenres() async throws {
        let (sut, view, _) = makeSUT(genres: .success(Genre.fixtures))

        sut.viewDidLoad()
        try await waitUntil { view.genres?.count == Genre.fixtures.count + 1 }

        #expect(view.genres?.first?.title == "All")
        #expect(view.genres?.dropFirst().map(\.title) == Genre.fixtures.map(\.name))
    }

    @Test("The tick sits on a preselected genre")
    func ticksThePreselectedGenre() async throws {
        let genre = try #require(Genre.fixtures.first)
        let (sut, view, _) = makeSUT(
            genres: .success(Genre.fixtures),
            selection: MoviesFilter(genreID: genre.id)
        )

        sut.viewDidLoad()
        try await waitUntil { view.genres?.count == Genre.fixtures.count + 1 }

        #expect(view.genres?.first(where: \.isChecked)?.title == genre.name)
    }

    @Test("With no genre chosen the tick sits on All")
    func ticksAllByDefault() async throws {
        let (sut, view, _) = makeSUT(genres: .success(Genre.fixtures))

        sut.viewDidLoad()
        try await waitUntil { view.genres?.count == Genre.fixtures.count + 1 }

        #expect(view.genres?.first?.isChecked == true)
    }

    @Test("Every sort option is shown, independent of the catalogue")
    func showsSortOptionsWithoutTheCatalogue() {
        let (sut, view, _) = makeSUT(genres: .failure(.regionRestricted))

        sut.viewDidLoad()

        #expect(view.sortOptions?.map(\.title) == MovieSortOption.allCases.map(\.title))
        #expect(view.sortOptions?.first(where: \.isChecked)?.title == MovieSortOption.popularityDescending.title)
    }

    @Test("Sorting still works while the genre catalogue is down")
    func sortsWhileTheCatalogueIsDown() async throws {
        let (sut, view, _) = makeSUT(genres: .failure(.regionRestricted))

        sut.viewDidLoad()
        try await waitUntil { view.genreFailure != nil }

        sut.didSelectSort(at: 1)

        #expect(view.sortOptions?[1].isChecked == true)
        #expect(view.sortOptions?[0].isChecked == false)
    }

    @Test("Choosing a genre moves the tick")
    func movesTheTick() async throws {
        let (sut, view, _) = makeSUT(genres: .success(Genre.fixtures))

        sut.viewDidLoad()
        try await waitUntil { view.genres?.count == Genre.fixtures.count + 1 }

        sut.didSelectGenre(at: 2)

        #expect(view.genres?[2].isChecked == true)
        #expect(view.genres?.filter(\.isChecked).count == 1)
    }

    @Test("The catalogue reports itself while it loads")
    func showsLoadingWhileFetching() {
        let (sut, view, _) = makeSUT(genres: .success(Genre.fixtures))

        sut.viewDidLoad()

        #expect(view.genreLoadingCount == 1)
    }

    @Test("A failed catalogue offers retry, and retrying refetches")
    func retryRefetchesTheCatalogue() async throws {
        let (sut, view, fetchGenres) = makeSUT(genres: .failure(.network(.offline)))

        sut.viewDidLoad()
        try await waitUntil { view.genreFailure?.retry == true }

        await fetchGenres.setResult(.success(Genre.fixtures))
        sut.didTapRetry()

        try await waitUntil { view.genres?.count == Genre.fixtures.count + 1 }
        #expect(await fetchGenres.calls.count == 2)
    }

    @Test("An unfixable failure offers no retry", arguments: [AppError.regionRestricted, .unauthorized])
    func hidesRetryForUnfixableFailures(error: AppError) async throws {
        let (sut, view, _) = makeSUT(genres: .failure(error))

        sut.viewDidLoad()
        try await waitUntil { view.genreFailure != nil }

        #expect(view.genreFailure?.retry == false)
        #expect(view.genreFailure?.message == error.message)
    }

    @Test("Apply reports the selection and closes the sheet")
    func applyReportsTheSelection() async throws {
        let applied = Box<[MoviesFilter]>([])
        let (sut, view, _) = makeSUT(
            genres: .success(Genre.fixtures),
            onApply: { applied.value.append($0) }
        )

        sut.viewDidLoad()
        try await waitUntil { view.genres?.count == Genre.fixtures.count + 1 }
        sut.didSelectGenre(at: 1)
        sut.didSelectSort(at: 2)
        sut.didTapApply()

        let genre = try #require(Genre.fixtures.first)
        #expect(applied.value == [MoviesFilter(genreID: genre.id, sort: MovieSortOption.allCases[2])])
        #expect(view.dismissCount == 1)
    }

    @Test("Cancel reports nothing and closes the sheet")
    func cancelReportsNothing() async throws {
        let applied = Box<[MoviesFilter]>([])
        let (sut, view, _) = makeSUT(
            genres: .success(Genre.fixtures),
            onApply: { applied.value.append($0) }
        )

        sut.viewDidLoad()
        try await waitUntil { view.genres?.count == Genre.fixtures.count + 1 }
        sut.didSelectGenre(at: 1)
        sut.didTapCancel()

        #expect(applied.value.isEmpty)
        #expect(view.dismissCount == 1)
    }

    @Test("Selecting All clears the genre")
    func selectingAllClearsTheGenre() async throws {
        let applied = Box<[MoviesFilter]>([])
        let genre = try #require(Genre.fixtures.first)
        let (sut, view, _) = makeSUT(
            genres: .success(Genre.fixtures),
            selection: MoviesFilter(genreID: genre.id),
            onApply: { applied.value.append($0) }
        )

        sut.viewDidLoad()
        try await waitUntil { view.genres?.count == Genre.fixtures.count + 1 }
        sut.didSelectGenre(at: 0)
        sut.didTapApply()

        #expect(applied.value.first?.genreID == nil)
    }

    @Test("An out-of-range selection is ignored rather than trapping")
    func ignoresOutOfRangeSelection() async throws {
        let (sut, view, _) = makeSUT(genres: .success(Genre.fixtures))

        sut.viewDidLoad()
        try await waitUntil { view.genres?.count == Genre.fixtures.count + 1 }

        sut.didSelectGenre(at: 99)
        sut.didSelectSort(at: 99)

        #expect(view.genres?.first?.isChecked == true)
    }

    // MARK: - Helpers

    private func makeSUT(
        genres: Result<[Genre], AppError>,
        selection: MoviesFilter = MoviesFilter(),
        onApply: @escaping (MoviesFilter) -> Void = { _ in },
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (MoviesFilterPresenter, MoviesFilterViewSpy, FetchGenresStub) {
        let fetchGenres = FetchGenresStub(result: genres)
        let view = MoviesFilterViewSpy()
        let sut = MoviesFilterPresenter(fetchGenres: fetchGenres, selection: selection, onApply: onApply)
        sut.view = view

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, view, fetchGenres)
    }
}

/// Records what the presenter asked the sheet to do.
@MainActor
final class MoviesFilterViewSpy: MoviesFilterView {
    private(set) var genres: [FilterRow]?
    private(set) var sortOptions: [FilterRow]?
    private(set) var genreLoadingCount = 0
    private(set) var genreFailure: (message: String, retry: Bool)?
    private(set) var dismissCount = 0

    func showGenres(_ rows: [FilterRow]) {
        genres = rows
    }

    func showGenreLoading() {
        genreLoadingCount += 1
        genres = nil
    }

    func showGenreFailure(_ message: String, retry: Bool) {
        genreFailure = (message, retry)
        genres = nil
    }

    func showSortOptions(_ rows: [FilterRow]) {
        sortOptions = rows
    }

    func dismiss() {
        dismissCount += 1
    }
}
