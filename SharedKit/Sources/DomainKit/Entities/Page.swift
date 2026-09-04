import Foundation

/// A single page of a paginated feed.
///
/// The domain is stateless: the accumulated list, the current page and the
/// loading flag live in presentation, so each of the six architectures paginates
/// its own way.
public struct Page<Item: Hashable & Sendable>: Hashable, Sendable {
    public let items: [Item]
    /// Number of this page, 1-based.
    public let page: Int
    public let totalPages: Int
    public let totalResults: Int

    public init(items: [Item], page: Int, totalPages: Int, totalResults: Int) {
        self.items = items
        self.page = page
        self.totalPages = totalPages
        self.totalResults = totalResults
    }

    public var hasNextPage: Bool { page < totalPages }

    public var nextPage: Int? { hasNextPage ? page + 1 : nil }

    public var isEmpty: Bool { items.isEmpty }
}
