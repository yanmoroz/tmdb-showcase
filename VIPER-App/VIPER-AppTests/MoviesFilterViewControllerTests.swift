import Testing
import UIKit
import PresentationKit
@testable import VIPER_App

/// The sheet's job is turning rows into cells and taps into reports. Which rows,
/// and where the tick sits, is `MoviesFilterPresenterTests`.
@MainActor
@Suite("MoviesFilterViewController")
final class MoviesFilterViewControllerTests {
    nonisolated(unsafe) private weak var trackedSUT: MoviesFilterViewController?
    private var trackedLocation: SourceLocation?

    private let presenter = MoviesFilterViewOutputSpy()

    deinit {
        if let trackedLocation {
            #expect(
                trackedSUT == nil,
                "The controller outlived the test — likely a retain cycle",
                sourceLocation: trackedLocation
            )
        }
    }

    // MARK: - Commands

    @Test("Rows become cells in both sections")
    func rowsBecomeCells() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showGenres([row("All", checked: true), row("Action"), row("Drama")])
            sut.showSortOptions([row("Most popular", checked: true), row("Highest rated")])

            #expect(sut.testTableView.numberOfSections == 2)
            #expect(sut.testTableView.numberOfRows(inSection: 0) == 3)
            #expect(sut.testTableView.numberOfRows(inSection: 1) == 2)
            #expect(sut.title(forRowAt: IndexPath(row: 1, section: 0)) == "Action")
        }
    }

    @Test("A ticked row shows a checkmark")
    func checkedRowShowsCheckmark() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showGenres([row("All"), row("Action", checked: true)])

            #expect(sut.accessoryType(forRowAt: IndexPath(row: 0, section: 0)) == .none)
            #expect(sut.accessoryType(forRowAt: IndexPath(row: 1, section: 0)) == .checkmark)
        }
    }

    @Test("The genre section carries its load state as one cell, leaving sort alone")
    func statusIsACellNotAnOverlay() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.showSortOptions([row("Most popular", checked: true), row("Highest rated")])

            sut.showGenreLoading()

            #expect(sut.testTableView.numberOfRows(inSection: 0) == 1)
            #expect(sut.genreStatus != nil)
            #expect(sut.testTableView.numberOfRows(inSection: 1) == 2)
        }
    }

    @Test("A retryable failure draws a button")
    func failureOffersRetry() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showGenreFailure("No internet connection.", retry: true)

            #expect(sut.genreStatus?.button.title == "Retry")
        }
    }

    @Test("An unfixable failure draws none")
    func failureWithoutRetry() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.showGenreFailure("TMDB is not available in your region.", retry: false)

            // `.empty()` always carries a button, so the title is what tells an
            // offered retry from an absent one.
            #expect(sut.genreStatus?.button.title == nil)
        }
    }

    // MARK: - Reports

    @Test("Loading the view is reported")
    func loadingIsReported() {
        autoreleasepool {
            let sut = makeSUT()

            sut.loadViewIfNeeded()

            #expect(presenter.events.contains(.viewDidLoad))
        }
    }

    @Test("Tapping a row reports its section and position")
    func rowTapsAreReported() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.showGenres([row("All", checked: true), row("Action")])
            sut.showSortOptions([row("Most popular", checked: true), row("Highest rated")])

            sut.selectRow(at: IndexPath(row: 1, section: 0))
            sut.selectRow(at: IndexPath(row: 0, section: 1))

            #expect(Array(presenter.events.suffix(2)) == [.didSelectGenre(1), .didSelectSort(0)])
        }
    }

    @Test("Tapping a status row reports nothing")
    func statusRowIsNotSelectable() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.showGenreFailure("No internet connection.", retry: true)

            sut.selectRow(at: IndexPath(row: 0, section: 0))

            #expect(!presenter.events.contains(.didSelectGenre(0)))
        }
    }

    @Test("Retry is reported")
    func retryIsReported() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()
            sut.showGenreFailure("No internet connection.", retry: true)

            sut.genreStatus?.buttonProperties.primaryAction?.performWithSender(nil, target: nil)

            #expect(presenter.events.last == .didTapRetry)
        }
    }

    @Test("Apply and Cancel are reported")
    func barButtonsAreReported() {
        autoreleasepool {
            let sut = makeSUT()
            sut.loadViewIfNeeded()

            sut.navigationItem.rightBarButtonItem?.primaryAction?.performWithSender(nil, target: nil)
            sut.navigationItem.leftBarButtonItem?.primaryAction?.performWithSender(nil, target: nil)

            #expect(Array(presenter.events.suffix(2)) == [.didTapApply, .didTapCancel])
        }
    }

    // MARK: - Helpers

    private func makeSUT(sourceLocation: SourceLocation = #_sourceLocation) -> MoviesFilterViewController {
        let sut = MoviesFilterViewController(presenter: presenter)

        trackedSUT = sut
        trackedLocation = sourceLocation
        return sut
    }

    private func row(_ title: String, checked: Bool = false) -> FilterRow {
        FilterRow(title: title, isChecked: checked)
    }
}

/// Records what the sheet reported.
@MainActor
final class MoviesFilterViewOutputSpy: MoviesFilterViewOutput {
    enum Event: Equatable {
        case viewDidLoad
        case didSelectGenre(Int)
        case didSelectSort(Int)
        case didTapRetry
        case didTapApply
        case didTapCancel
    }

    private(set) var events: [Event] = []

    func viewDidLoad() { events.append(.viewDidLoad) }

    func didSelectGenre(at index: Int) { events.append(.didSelectGenre(index)) }
    func didSelectSort(at index: Int) { events.append(.didSelectSort(index)) }
    func didTapRetry() { events.append(.didTapRetry) }

    func didTapApply() { events.append(.didTapApply) }
    func didTapCancel() { events.append(.didTapCancel) }
}

// MARK: - Scaffolding the controller cannot be touched without

@MainActor
private extension MoviesFilterViewController {
    var testTableView: UITableView {
        guard let tableView = view.firstSubview(of: UITableView.self) else {
            preconditionFailure("MoviesFilterViewController stopped containing a UITableView")
        }
        return tableView
    }

    func title(forRowAt indexPath: IndexPath) -> String? {
        autoreleasepool {
            let cell = testTableView.dataSource?.tableView(testTableView, cellForRowAt: indexPath)
            return (cell?.contentConfiguration as? UIListContentConfiguration)?.text
        }
    }

    /// The genre section's load state, a cell rather than a screen overlay.
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
}
