import Testing
import DomainKit

@Suite("AppError")
struct AppErrorTests {
    @Test("Retrying only makes sense for transient failures", arguments: [
        AppError.rateLimited,
        AppError.server(statusCode: 500),
        AppError.network(.offline),
        AppError.network(.timedOut),
    ])
    func retryable(error: AppError) {
        #expect(error.isRetryable)
    }

    @Test("Region block, key and malformed response are not cured by retrying", arguments: [
        AppError.regionRestricted,
        AppError.unauthorized,
        AppError.notFound,
        AppError.decoding,
        AppError.cancelled,
        AppError.unknown,
    ])
    func notRetryable(error: AppError) {
        #expect(!error.isRetryable)
    }

    @Test("Server errors with different statuses stay distinguishable")
    func serverStatusIsPartOfIdentity() {
        #expect(AppError.server(statusCode: 500) != AppError.server(statusCode: 503))
        #expect(AppError.server(statusCode: 500) == AppError.server(statusCode: 500))
    }
}
