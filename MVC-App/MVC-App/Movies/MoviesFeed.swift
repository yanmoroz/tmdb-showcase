import Foundation
import DomainKit

extension MoviesViewController {
    /// The accumulated answer to one query.
    ///
    /// `query` is a `let` on purpose: page 3 of `.popular` and page 3 of a search
    /// are different things, so changing the question has to mean building a new
    /// `Feed`. That makes "pages accumulated for a query we are no longer asking"
    /// unrepresentable instead of a reset somebody has to remember.
    struct Feed {
        let query: MoviesQuery

        private(set) var movies: [Movie] = []
        private(set) var loadedPage = 0
        private(set) var totalPages = 1

        var isEmpty: Bool { movies.isEmpty }
        var count: Int { movies.count }

        /// `nil` once the pages run out.
        var nextPage: Int? { loadedPage < totalPages ? loadedPage + 1 : nil }

        subscript(item: Int) -> Movie { movies[item] }

        func index(of id: Movie.ID) -> Int? {
            movies.firstIndex { $0.id == id }
        }

        mutating func append(_ page: Page<Movie>) {
            movies.append(contentsOf: page.items)
            loadedPage = page.page
            totalPages = page.totalPages
        }
    }
}
