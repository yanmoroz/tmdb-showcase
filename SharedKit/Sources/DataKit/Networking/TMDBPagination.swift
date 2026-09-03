enum TMDBPagination {
    /// TMDB answers 400 above this page, so requests and `totalPages` are both
    /// clamped — otherwise `Page.hasNextPage` would promise an unfetchable page.
    static let maxPage = 500

    static func clamp(_ page: Int) -> Int {
        min(max(page, 1), maxPage)
    }
}
