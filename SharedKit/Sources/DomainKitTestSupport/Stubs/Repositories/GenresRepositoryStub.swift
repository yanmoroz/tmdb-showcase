import Foundation
import DomainKit

/// A configurable ``GenresRepository`` stub with a call log.
public actor GenresRepositoryStub: GenresRepository {
    public private(set) var genresCalls: [GenresCall] = []

    private var genresResult: Result<[Genre], AppError>

    public init(genresResult: Result<[Genre], AppError> = .success(Genre.fixtures)) {
        self.genresResult = genresResult
    }

    public func setGenresResult(_ result: Result<[Genre], AppError>) {
        genresResult = result
    }

    public func genres() async throws(AppError) -> [Genre] {
        genresCalls.append(GenresCall())
        return try genresResult.get()
    }
}
