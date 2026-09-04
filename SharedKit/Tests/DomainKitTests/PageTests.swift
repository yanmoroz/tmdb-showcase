import Testing
import DomainKit
import DomainKitTestSupport

@Suite("Page")
struct PageTests {
    @Test("There is a next page until the current one is last")
    func hasNextPageInMiddle() {
        let page = Page.fixture(items: Movie.fixtures(count: 20), page: 2, totalPages: 5)

        #expect(page.hasNextPage)
        #expect(page.nextPage == 3)
    }

    @Test("The last page has no next")
    func noNextPageOnLast() {
        let page = Page.fixture(items: Movie.fixtures(count: 3), page: 5, totalPages: 5)

        #expect(!page.hasNextPage)
        #expect(page.nextPage == nil)
    }

    @Test("A single page has no next")
    func singlePage() {
        let page = Page.fixture(items: Movie.fixtures(count: 3), page: 1, totalPages: 1)

        #expect(!page.hasNextPage)
        #expect(page.nextPage == nil)
    }

    @Test("An empty result is empty and has no continuation")
    func empty() {
        let page = Page<Movie>.fixture(items: [], totalPages: 0)

        #expect(page.isEmpty)
        #expect(page.totalResults == 0)
        #expect(!page.hasNextPage)
        #expect(page.nextPage == nil)
    }
}
