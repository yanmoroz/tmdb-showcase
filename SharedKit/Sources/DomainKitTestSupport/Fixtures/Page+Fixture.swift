import DomainKit

extension Page {
    public static func fixture(
        items: [Item],
        page: Int = 1,
        totalPages: Int = 1,
        totalResults: Int? = nil
    ) -> Page {
        Page(
            items: items,
            page: page,
            totalPages: totalPages,
            totalResults: totalResults ?? items.count
        )
    }

    /// An empty feed: no items and no page to follow.
    public static func empty(page: Int = 1) -> Page {
        Page(items: [], page: page, totalPages: 0, totalResults: 0)
    }
}
