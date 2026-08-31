import Testing
import DomainKit
import DomainKitTestSupport

@Suite("Page")
struct PageTests {
    @Test("Есть следующая страница, пока текущая не последняя")
    func hasNextPageInMiddle() {
        let page = Page.fixture(items: Movie.fixtures(count: 20), page: 2, totalPages: 5)

        #expect(page.hasNextPage)
        #expect(page.nextPage == 3)
    }

    @Test("На последней странице следующей нет")
    func noNextPageOnLast() {
        let page = Page.fixture(items: Movie.fixtures(count: 3), page: 5, totalPages: 5)

        #expect(!page.hasNextPage)
        #expect(page.nextPage == nil)
    }

    @Test("Единственная страница не имеет следующей")
    func singlePage() {
        let page = Page.fixture(items: Movie.fixtures(count: 3), page: 1, totalPages: 1)

        #expect(!page.hasNextPage)
        #expect(page.nextPage == nil)
    }

    @Test("Пустая выдача пуста и не имеет продолжения")
    func empty() {
        let page = Page<Movie>.empty()

        #expect(page.isEmpty)
        #expect(page.totalResults == 0)
        #expect(!page.hasNextPage)
        #expect(page.nextPage == nil)
    }

    @Test("Пустая выдача запоминает номер запрошенной страницы")
    func emptyKeepsRequestedPage() {
        #expect(Page<Movie>.empty(page: 7).page == 7)
    }
}
