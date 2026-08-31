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
}
