import Testing
import DomainKit

@Suite("AppError")
struct AppErrorTests {
    @Test("Повтор имеет смысл только для временных сбоев", arguments: [
        AppError.rateLimited,
        AppError.server(statusCode: 500),
        AppError.network(.offline),
        AppError.network(.timedOut),
    ])
    func retryable(error: AppError) {
        #expect(error.isRetryable)
    }

    @Test("Гео-блокировка, ключ и битый ответ повтором не лечатся", arguments: [
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

    @Test("Ошибки сервера с разным статусом различимы")
    func serverStatusIsPartOfIdentity() {
        #expect(AppError.server(statusCode: 500) != AppError.server(statusCode: 503))
        #expect(AppError.server(statusCode: 500) == AppError.server(statusCode: 500))
    }
}
