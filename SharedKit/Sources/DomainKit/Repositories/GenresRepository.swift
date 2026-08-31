import Foundation

/// The genre catalogue. Implemented in DataKit, and caching belongs there too:
/// the list changes very rarely.
public protocol GenresRepository: Sendable {
    func genres() async throws(AppError) -> [Genre]
}
