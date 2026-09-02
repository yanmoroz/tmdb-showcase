import Testing
import UIKit
import DomainKit
import DomainKitTestSupport
import DataKit
@testable import MVC_App

@MainActor
@Suite("MoviesViewController")
final class MoviesViewControllerTests {
    /// Swift Testing builds one suite instance per test, so `deinit` works as
    /// teardown: by then the test's own local references are gone.
    private weak var trackedSUT: MoviesViewController?
    private var trackedLocation: SourceLocation?

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "Контроллер пережил тест — вероятен цикл удержания",
                sourceLocation: trackedLocation
            )
        }
    }

    @Test("Загруженная страница попадает в коллекцию")
    func showsLoadedPage() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 8), totalPages: 3)
        let (sut, _) = makeSUT(result: .success(page))

        sut.loadViewIfNeeded()

        // waitUntil records an issue on timeout, so reaching the count is the
        // assertion — repeating it below would only double-report one failure.
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 8 }
    }

    @Test("Первая страница запрашивается с номером 1")
    func requestsFirstPage() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 4))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        let calls = await fetchMovies.calls
        #expect(calls == [MoviesCall(query: .popular, page: 1)])
    }

    @Test("Ошибка не наполняет коллекцию")
    func keepsCollectionEmptyOnFailure() async throws {
        let (sut, fetchMovies) = makeSUT(result: .failure(.regionRestricted))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 0)
    }

    @Test("Показ ячейки у конца списка догружает следующую страницу")
    func loadsNextPageNearEnd() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 20), totalPages: 5)
        let (sut, fetchMovies) = makeSUT(result: .success(page))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 20 }

        sut.simulateCellDisplayed(at: 19)
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 40 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.page) == [1, 2])
    }

    @Test("Повторяемая ошибка даёт кнопку повтора")
    func offersRetryForRetryableError() async throws {
        let (sut, fetchMovies) = makeSUT(result: .failure(.network(.offline)))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }
        let configuration = try #require(sut.currentUnavailableConfiguration)

        #expect(configuration.button.title == "Повторить")
        #expect(configuration.secondaryText == AppError.network(.offline).message)
    }

    @Test("Гео-блокировка кнопку повтора не предлагает")
    func hidesRetryForRegionRestricted() async throws {
        let (sut, fetchMovies) = makeSUT(result: .failure(.regionRestricted))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }
        let configuration = try #require(sut.currentUnavailableConfiguration)

        // .regionRestricted is not isRetryable: without a VPN a retry returns
        // the same 403. `.empty()` always carries a button, so the title tells
        // an offered retry from an absent one.
        #expect(configuration.button.title == nil)
    }

    @Test("Отмена не оставляет экран на вечном спиннере")
    func escapesLoadingOnCancellation() async throws {
        let (sut, fetchMovies) = makeSUT(result: .failure(.cancelled))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }
        let configuration = try #require(sut.currentUnavailableConfiguration)

        // The .loading spinner has no exit of its own: leaving the state
        // untouched on cancellation strands the user on it forever.
        #expect(configuration.text == "Не удалось загрузить")
        #expect(configuration.button.title == "Повторить")
    }

    @Test("За последней страницей продолжения не запрашивается")
    func stopsAtLastPage() async throws {
        let page = Page.fixture(items: Movie.fixtures(count: 6), totalPages: 1)
        let (sut, fetchMovies) = makeSUT(result: .success(page))

        sut.loadViewIfNeeded()
        try await waitUntil { sut.testCollectionView.numberOfItems(inSection: 0) == 6 }

        for _ in 0..<3 {
            sut.simulateCellDisplayed(at: 5)
        }
        await drainPendingWork()

        let calls = await fetchMovies.calls
        #expect(calls.map(\.page) == [1])
        #expect(sut.testCollectionView.numberOfItems(inSection: 0) == 6)
    }

    // MARK: - Поиск

    @Test("Введённый текст уходит в домен поисковым запросом")
    func typedTextBecomesSearchQuery() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch("dune")
        try await waitUntil { await fetchMovies.calls.count == 2 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [.popular, .search(.fixture("dune"))])
    }

    @Test("Быстрый набор даёт один запрос с последним текстом")
    func rapidTypingCollapsesToLastQuery() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        // Три нажатия подряд: промежуточные запросы уходить не должны.
        for text in ["d", "du", "dune"] {
            sut.simulateSearch(text)
        }
        await drainPendingWork()
        try await waitUntil { await fetchMovies.calls.count == 2 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [.popular, .search(.fixture("dune"))])
    }

    @Test("Пустой ввод не идёт в сеть поиском", arguments: ["", "   ", "\n\t"])
    func blankInputStaysOnPopular(input: String) async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch(input)
        await drainPendingWork()

        // SearchText отвергает пустой ввод, а .popular уже показан — повторять
        // тот же запрос незачем.
        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [.popular])
    }

    @Test("Очистка поля возвращает популярное")
    func clearingSearchReturnsToPopular() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch("dune")
        try await waitUntil { await fetchMovies.calls.count == 2 }

        sut.simulateSearch("")
        try await waitUntil { await fetchMovies.calls.count == 3 }

        let calls = await fetchMovies.calls
        #expect(calls.map(\.query) == [.popular, .search(.fixture("dune")), .popular])
    }

    @Test("Повторный ввод того же текста не перезапрашивает")
    func repeatingSameTextDoesNotReload() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: Movie.fixtures(count: 3))))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch("dune")
        try await waitUntil { await fetchMovies.calls.count == 2 }

        // Обрезка пробелов даёт тот же SearchText, значит и тот же MoviesQuery.
        sut.simulateSearch("  dune  ")
        await drainPendingWork()

        let calls = await fetchMovies.calls
        #expect(calls.count == 2)
    }

    @Test("Пустая выдача поиска показывает первостороннее состояние")
    func emptySearchShowsSearchConfiguration() async throws {
        let (sut, fetchMovies) = makeSUT(result: .success(.fixture(items: [])))

        sut.loadViewIfNeeded()
        try await waitUntil { await !fetchMovies.calls.isEmpty }

        sut.simulateSearch("qqqqzzz")
        try await waitUntil { await fetchMovies.calls.count == 2 }
        let configuration = try #require(sut.currentUnavailableConfiguration)

        // .search() пишет свой текст сам; наше «Фильмов нет» тут было бы враньём.
        #expect(configuration.text != "Фильмов нет")
        #expect(configuration.text != nil)
    }

    // MARK: - Factory

    /// The view is deliberately not loaded here: `loadViewIfNeeded()` starts
    /// the request, and that "act" step belongs in the test body.
    ///
    /// The controller holds a `Task` and targets `UIRefreshControl`, so a
    /// retain cycle is easy to introduce — hence the leak tracking.
    private func makeSUT(
        result: Result<Page<Movie>, AppError>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (sut: MoviesViewController, fetchMovies: FetchMoviesStub) {
        let fetchMovies = FetchMoviesStub(result: result)
        let sut = MoviesViewController(
            fetchMovies: fetchMovies,
            imageURLBuilder: TMDBImageURLBuilder(configuration: TMDBConfiguration(accessToken: "test")),
            // Zero interval keeps the debounce observable without waiting on
            // wall-clock: draining the main actor is enough to let it fire.
            searchDebounce: .zero
        )
        trackedSUT = sut
        trackedLocation = sourceLocation
        return (sut, fetchMovies)
    }
}

// MARK: - Scaffolding the controller cannot be touched without

@MainActor
private extension MoviesViewController {
    var testCollectionView: UICollectionView {
        guard let collectionView = view.firstCollectionView else {
            preconditionFailure("MoviesViewController перестал содержать UICollectionView")
        }
        return collectionView
    }

    /// UIKit rebuilds the configuration lazily, at a layout pass that never
    /// happens in a windowless test.
    ///
    /// The `autoreleasepool` is required: layout autoreleases objects holding
    /// the controller, and without draining the pool the leak check reads a
    /// deferred release as a retain cycle.
    var currentUnavailableConfiguration: UIContentUnavailableConfiguration? {
        autoreleasepool {
            setNeedsUpdateContentUnavailableConfiguration()
            view.layoutIfNeeded()
        }
        return contentUnavailableConfiguration as? UIContentUnavailableConfiguration
    }

    func simulateSearch(_ text: String) {
        guard let searchController = navigationItem.searchController else {
            preconditionFailure("MoviesViewController stopped installing a UISearchController")
        }
        searchController.searchBar.text = text
        updateSearchResults(for: searchController)
    }

    func simulateCellDisplayed(at item: Int) {
        collectionView(
            testCollectionView,
            willDisplay: UICollectionViewCell(),
            forItemAt: IndexPath(item: item, section: 0)
        )
    }
}

/// Hands the main actor to whatever the controller may have enqueued.
///
/// Its load task inherits `MainActor` from the caller, so it cannot start while
/// a `@MainActor` test body runs. Yielding gives it that chance without leaning
/// on wall-clock time: a fixed sleep would let a slow machine hide a request
/// that does get sent, just after the window closes.
private func drainPendingWork(iterations: Int = 10) async {
    for _ in 0..<iterations {
        await Task.yield()
    }
}

/// The controller's `Task` is not exposed, so waiting means polling state.
private func waitUntil(
    timeout: Duration = .seconds(2),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () async -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Условие не выполнилось за \(timeout)", sourceLocation: sourceLocation)
}

private extension UIView {
    var firstCollectionView: UICollectionView? {
        if let collectionView = self as? UICollectionView { return collectionView }
        for subview in subviews {
            if let found = subview.firstCollectionView { return found }
        }
        return nil
    }
}
