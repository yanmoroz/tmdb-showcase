import Foundation
import DomainKit

public actor FetchGenresStub: FetchGenresUseCase {
    public private(set) var calls: [GenresCall] = []

    private var result: Result<[Genre], AppError>

    public init(result: Result<[Genre], AppError> = .success(Genre.fixtures)) {
        self.result = result
    }

    public func setResult(_ result: Result<[Genre], AppError>) {
        self.result = result
    }

    public func callAsFunction() async throws(AppError) -> [Genre] {
        calls.append(GenresCall())
        return try result.get()
    }
}
