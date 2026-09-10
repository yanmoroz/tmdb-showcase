import Testing
import Foundation
import DomainKit
import DomainKitTestSupport
import PresentationKit
@testable import VIPER_App

/// Synchronous throughout: with the interactor faked, a test plays its part by
/// calling the output methods itself.
@MainActor
@Suite("MoviesFilterPresenter")
final class MoviesFilterPresenterTests {
    private weak var trackedSUT: MoviesFilterPresenter?
    private var trackedLocation: SourceLocation?

    private let view = MoviesFilterViewSpy()
    private let interactor = MoviesFilterInteractorSpy()
    private let router = MoviesFilterRouterSpy()
    private let moduleOutput = MoviesFilterModuleOutputSpy()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The presenter outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    // MARK: - Catalogue

    @Test("The catalogue loads and puts an \"All\" row above the genres")
    func showsAllAboveTheGenres() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoadGenres(Genre.fixtures)

        #expect(view.genres?.first?.title == "All")
        #expect(view.genres?.dropFirst().map(\.title) == Genre.fixtures.map(\.name))
    }

    @Test("The tick sits on a preselected genre")
    func ticksThePreselectedGenre() throws {
        let genre = try #require(Genre.fixtures.first)
        let sut = makeSUT(selection: MoviesFilter(genreID: genre.id))

        sut.viewDidLoad()
        sut.didLoadGenres(Genre.fixtures)

        #expect(view.genres?.first(where: \.isChecked)?.title == genre.name)
    }

    @Test("With no genre chosen the tick sits on All")
    func ticksAllByDefault() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoadGenres(Genre.fixtures)

        #expect(view.genres?.first?.isChecked == true)
    }

    @Test("Opening the sheet asks for the catalogue and says it is loading")
    func showsLoadingWhileFetching() {
        let sut = makeSUT()

        sut.viewDidLoad()

        #expect(interactor.loadCount == 1)
        #expect(view.genreLoadingCount == 1)
    }

    @Test("A failed catalogue offers retry, and retrying asks again")
    func retryRefetchesTheCatalogue() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didFailToLoadGenres(with: .network(.offline))
        #expect(view.genreFailure?.retry == true)

        sut.didTapRetry()
        sut.didLoadGenres(Genre.fixtures)

        #expect(interactor.loadCount == 2)
        #expect(view.genres?.count == Genre.fixtures.count + 1)
    }

    @Test("An unfixable failure offers no retry", arguments: [AppError.regionRestricted, .unauthorized])
    func hidesRetryForUnfixableFailures(error: AppError) {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didFailToLoadGenres(with: error)

        #expect(view.genreFailure?.retry == false)
        #expect(view.genreFailure?.message == error.message)
    }

    // MARK: - Sort

    @Test("Every sort option is shown, independent of the catalogue")
    func showsSortOptionsWithoutTheCatalogue() {
        let sut = makeSUT()

        sut.viewDidLoad()

        #expect(view.sortOptions?.map(\.title) == MovieSortOption.allCases.map(\.title))
        #expect(view.sortOptions?.first(where: \.isChecked)?.title == MovieSortOption.popularityDescending.title)
    }

    @Test("Sorting still works while the genre catalogue is down")
    func sortsWhileTheCatalogueIsDown() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didFailToLoadGenres(with: .regionRestricted)
        sut.didSelectSort(at: 1)

        #expect(view.sortOptions?[1].isChecked == true)
        #expect(view.sortOptions?[0].isChecked == false)
    }

    // MARK: - Selection

    @Test("Choosing a genre moves the tick")
    func movesTheTick() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoadGenres(Genre.fixtures)
        sut.didSelectGenre(at: 2)

        #expect(view.genres?[2].isChecked == true)
        #expect(view.genres?.filter(\.isChecked).count == 1)
    }

    @Test("Apply reports the selection and closes the sheet")
    func applyReportsTheSelection() throws {
        let genre = try #require(Genre.fixtures.first)
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoadGenres(Genre.fixtures)
        sut.didSelectGenre(at: 1)
        sut.didSelectSort(at: 2)
        sut.didTapApply()

        #expect(moduleOutput.applied == [MoviesFilter(genreID: genre.id, sort: MovieSortOption.allCases[2])])
        #expect(router.dismissCount == 1)
    }

    @Test("Cancel reports nothing and closes the sheet")
    func cancelReportsNothing() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoadGenres(Genre.fixtures)
        sut.didSelectGenre(at: 1)
        sut.didTapCancel()

        #expect(moduleOutput.applied.isEmpty)
        #expect(router.dismissCount == 1)
    }

    @Test("Selecting All clears the genre")
    func selectingAllClearsTheGenre() throws {
        let genre = try #require(Genre.fixtures.first)
        let sut = makeSUT(selection: MoviesFilter(genreID: genre.id))

        sut.viewDidLoad()
        sut.didLoadGenres(Genre.fixtures)
        sut.didSelectGenre(at: 0)
        sut.didTapApply()

        #expect(moduleOutput.applied.count == 1)
        #expect(moduleOutput.applied.first?.genreID == nil)
    }

    @Test("An out-of-range selection is ignored rather than trapping")
    func ignoresOutOfRangeSelection() {
        let sut = makeSUT()

        sut.viewDidLoad()
        sut.didLoadGenres(Genre.fixtures)
        sut.didSelectGenre(at: 99)
        sut.didSelectSort(at: 99)

        #expect(view.genres?.first?.isChecked == true)
    }

    // MARK: - Helpers

    private func makeSUT(
        selection: MoviesFilter = MoviesFilter(),
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> MoviesFilterPresenter {
        let sut = MoviesFilterPresenter(
            interactor: interactor,
            router: router,
            selection: selection,
            moduleOutput: moduleOutput
        )
        sut.view = view

        trackedSUT = sut
        trackedLocation = sourceLocation
        return sut
    }
}

/// Records what the presenter asked the sheet to do.
@MainActor
final class MoviesFilterViewSpy: MoviesFilterView {
    private(set) var genres: [FilterRow]?
    private(set) var sortOptions: [FilterRow]?
    private(set) var genreLoadingCount = 0
    private(set) var genreFailure: (message: String, retry: Bool)?

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
}

@MainActor
final class MoviesFilterInteractorSpy: MoviesFilterInteractorInput {
    private(set) var loadCount = 0

    func loadGenres() {
        loadCount += 1
    }
}

@MainActor
final class MoviesFilterRouterSpy: MoviesFilterRouterInput {
    private(set) var dismissCount = 0

    func dismiss() {
        dismissCount += 1
    }
}

/// Stands in for the screen the sheet reports to.
@MainActor
final class MoviesFilterModuleOutputSpy: MoviesFilterModuleOutput {
    private(set) var applied: [MoviesFilter] = []

    func didApplyFilter(_ filter: MoviesFilter) {
        applied.append(filter)
    }
}
