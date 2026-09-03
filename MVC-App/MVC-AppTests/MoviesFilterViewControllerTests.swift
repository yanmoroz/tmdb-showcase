import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
@testable import MVC_App

@MainActor
@Suite("MoviesFilterViewController")
final class MoviesFilterViewControllerTests {
    private weak var trackedSUT: MoviesFilterViewController?
    private var trackedLocation: SourceLocation?

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The filter controller outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    @Test("The catalogue loads and puts an \"All\" row above the genres")
    func loadsCatalogueWithAnyGenreRow() async throws {
        let (sut, fetchGenres, _) = makeSUT()

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchGenres.calls.isEmpty }
        try await waitUntil { sut.testTableView.numberOfRows(inSection: 0) == Genre.fixtures.count + 1 }

        #expect(sut.title(forRowAt: IndexPath(row: 0, section: 0)) == "All")
        #expect(sut.title(forRowAt: IndexPath(row: 1, section: 0)) == "Action")

        // No genre chosen, so the tick belongs to "All" — the nil == nil arm of
        // the comparison, which nothing else observes.
        #expect(sut.accessoryType(forRowAt: IndexPath(row: 0, section: 0)) == .checkmark)
        #expect(sut.accessoryType(forRowAt: IndexPath(row: 1, section: 0)) == .none)
    }

    @Test("The tick sits on a preselected genre")
    func checksPreselectedGenre() async throws {
        let (sut, _, _) = makeSUT(selection: MoviesFilter(genreID: 35))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testTableView.numberOfRows(inSection: 0) == Genre.fixtures.count + 1 }

        // Comedy is fixture 35, at row 2 once "All" takes row 0.
        #expect(sut.accessoryType(forRowAt: IndexPath(row: 2, section: 0)) == .checkmark)
        #expect(sut.accessoryType(forRowAt: IndexPath(row: 0, section: 0)) == .none)
    }

    @Test("Every sort option is shown, independent of the catalogue")
    func showsEverySortOption() async throws {
        let (sut, fetchGenres, _) = makeSUT(genres: .failure(.network(.offline)))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchGenres.calls.isEmpty }

        // The sort section is static: a genre catalogue failure does not touch it.
        #expect(sut.testTableView.numberOfRows(inSection: 1) == MovieSortOption.allCases.count)
        // And nothing covers it: the failure belongs to the genre section alone.
        #expect(sut.currentUnavailableConfiguration == nil)
    }

    @Test("Sorting still works while the genre catalogue is down")
    func failedCatalogueKeepsSortUsable() async throws {
        let (sut, _, applied) = makeSUT(genres: .failure(.network(.offline)))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.genreStatus != nil }

        // The genre section collapses to one status row; sort is untouched.
        #expect(sut.testTableView.numberOfRows(inSection: 0) == 1)
        // "Usable" means reachable, not merely present in the data source.
        #expect(sut.currentUnavailableConfiguration == nil)

        sut.selectRow(at: IndexPath(row: 1, section: 1))
        sut.tapBarButton(sut.navigationItem.rightBarButtonItem)

        let reported = try #require(applied.value)
        #expect(reported.sort == .ratingDescending)

        // Nothing above suspends, so the status cell's button and its UIAction
        // are still sitting in an outer autorelease pool when `deinit` runs its
        // leak check. Yielding drains them; without it a deferred release reads
        // as a retain cycle.
        await drainPendingWork()
    }

    @Test("A failed catalogue offers retry, and retry refetches")
    func retriesFailedCatalogue() async throws {
        let (sut, fetchGenres, _) = makeSUT(genres: .failure(.network(.offline)))

        sut.loadViewIfNeeded()
        // The stub records its call before the load task hops back to assign the
        // state, so waiting on the call can outrun the state it is a proxy for.
        try await waitUntil { sut.genreStatus?.button.title == "Retry" }

        let configuration = try #require(sut.genreStatus)

        autoreleasepool {
            configuration.buttonProperties.primaryAction?.performWithSender(
                nil,
                target: nil
            )
        }
        try await waitUntil { await fetchGenres.calls.count == 2 }
    }

    /// The mirror of `hidesRetryForRegionRestricted` on the movies screen: without
    /// a VPN the same 403 comes back every time, so the button would be a dead end.
    @Test("A region block offers no retry", arguments: [
        AppError.regionRestricted,
        .unauthorized,
        .notFound,
        .decoding,
    ])
    func hidesRetryForUnfixableFailures(error: AppError) async throws {
        let (sut, _, _) = try makeSUT(genres: .failure(error))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.genreStatus?.secondaryText == error.message }

        #expect(sut.genreStatus?.button.title == nil)
    }

    @Test("Apply reports the selection through the closure")
    func applyReportsSelection() async throws {
        let (sut, fetchGenres, applied) = makeSUT(selection: MoviesFilter(genreID: 28))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchGenres.calls.isEmpty }

        sut.selectRow(at: IndexPath(row: 1, section: 1))
        sut.tapBarButton(sut.navigationItem.rightBarButtonItem)

        let reported = try #require(applied.value)
        #expect(reported == MoviesFilter(genreID: 28, sort: .ratingDescending))
    }

    @Test("Cancel reports nothing")
    func cancelReportsNothing() async throws {
        let (sut, _, applied) = makeSUT()

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testTableView.numberOfRows(inSection: 0) == Genre.fixtures.count + 1 }

        sut.selectRow(at: IndexPath(row: 1, section: 0))
        sut.tapBarButton(sut.navigationItem.leftBarButtonItem)

        #expect(applied.value == nil)
    }

    // MARK: - Factory

    private func makeSUT(
        genres: Result<[Genre], AppError> = .success(Genre.fixtures),
        selection: MoviesFilter = MoviesFilter(),
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (sut: MoviesFilterViewController, fetchGenres: FetchGenresStub, applied: Box<MoviesFilter?>) {
        let fetchGenres = FetchGenresStub(result: genres)
        let applied = Box<MoviesFilter?>(nil)
        let sut = MoviesFilterViewController(
            fetchGenres: fetchGenres,
            selection: selection
        ) { applied.value = $0 }

        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchGenres, applied)
    }
}

// MARK: - Scaffolding

@MainActor
private extension MoviesFilterViewController {
    /// Every accessor here drains an `autoreleasepool`: touching the view
    /// hierarchy autoreleases objects that hold the controller, and the leak
    /// check in `deinit` would otherwise read a deferred release as a cycle.
    var testTableView: UITableView {
        autoreleasepool {
            guard let tableView = view.firstSubview(of: UITableView.self) else {
                preconditionFailure("MoviesFilterViewController stopped containing a UITableView")
            }
            return tableView
        }
    }

    var currentUnavailableConfiguration: UIContentUnavailableConfiguration? {
        autoreleasepool {
            setNeedsUpdateContentUnavailableConfiguration()
            view.layoutIfNeeded()
        }
        return contentUnavailableConfiguration as? UIContentUnavailableConfiguration
    }

    func title(forRowAt indexPath: IndexPath) -> String? {
        autoreleasepool {
            let cell = testTableView.dataSource?.tableView(testTableView, cellForRowAt: indexPath)
            return (cell?.contentConfiguration as? UIListContentConfiguration)?.text
        }
    }

    /// The genre section's load state, now a cell rather than a screen overlay.
    var genreStatus: UIContentUnavailableConfiguration? {
        autoreleasepool {
            let cell = testTableView.dataSource?.tableView(
                testTableView,
                cellForRowAt: IndexPath(row: 0, section: 0)
            )
            return cell?.contentConfiguration as? UIContentUnavailableConfiguration
        }
    }

    func accessoryType(forRowAt indexPath: IndexPath) -> UITableViewCell.AccessoryType {
        autoreleasepool {
            guard let cell = testTableView.dataSource?.tableView(testTableView, cellForRowAt: indexPath) else {
                preconditionFailure("MoviesFilterViewController stopped serving cells")
            }
            return cell.accessoryType
        }
    }

    func selectRow(at indexPath: IndexPath) {
        autoreleasepool {
            testTableView.delegate?.tableView?(testTableView, didSelectRowAt: indexPath)
        }
    }

    func tapBarButton(_ item: UIBarButtonItem?) {
        autoreleasepool {
            item?.primaryAction?.performWithSender(nil, target: nil)
        }
    }
}
