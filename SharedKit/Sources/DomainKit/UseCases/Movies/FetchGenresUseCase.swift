import Foundation

/// The genre catalogue behind the filter chips on the Movies screen.
public protocol FetchGenresUseCase: Sendable {
    func callAsFunction() async throws(AppError) -> [Genre]
}

public struct FetchGenres: FetchGenresUseCase {
    private let repository: any GenresRepository

    public init(repository: any GenresRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws(AppError) -> [Genre] {
        try await repository.genres()
    }
}
