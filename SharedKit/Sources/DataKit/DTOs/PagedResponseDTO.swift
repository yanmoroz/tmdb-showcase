import Foundation
import DomainKit

struct PagedResponseDTO<Item: Decodable & Sendable>: Decodable, Sendable {
    let page: Int
    let results: [Item]
    let totalPages: Int
    let totalResults: Int
}

extension PagedResponseDTO {
    func toDomain<Element: Hashable & Sendable>(
        _ transform: (Item) -> Element
    ) -> Page<Element> {
        Page(
            items: results.map(transform),
            page: page,
            // /movie/popular reports ~50 000 pages while refusing anything past
            // 500, so an unclamped totalPages would make hasNextPage lie.
            totalPages: min(totalPages, TMDBPagination.maxPage),
            totalResults: totalResults
        )
    }
}
