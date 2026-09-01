import Testing
import Foundation
import DomainKit
@testable import DataKit

@Suite("Классификация ошибок")
struct ErrorClassificationTests {
    @Test("Коды ответа раскладываются по доменным ошибкам", arguments: [
        (401, AppError.unauthorized),
        (404, AppError.notFound),
        (429, AppError.rateLimited),
        (500, AppError.server(statusCode: 500)),
        (502, AppError.server(statusCode: 502)),
        (599, AppError.server(statusCode: 599)),
    ])
    func classifiesStatusCodes(statusCode: Int, expected: AppError) {
        #expect(AppError(httpStatusCode: statusCode, body: Data()) == expected)
    }

    @Test("403 без тела — гео-блокировка CDN")
    func emptyForbiddenIsRegionRestricted() {
        #expect(AppError(httpStatusCode: 403, body: Data()) == .regionRestricted)
    }

    @Test("403 с телом TMDB — отказ по токену, а не по региону")
    func structuredForbiddenIsUnauthorized() throws {
        let body = try TestFixtures.data("error_401")

        // Иначе пользователю с битым токеном посоветовали бы включить VPN.
        #expect(AppError(httpStatusCode: 403, body: body) == .unauthorized)
    }

    @Test("404 и 429 не попадают в .server")
    func dedicatedCasesWinOverServer() {
        #expect(AppError(httpStatusCode: 404, body: Data()) != .server(statusCode: 404))
        #expect(AppError(httpStatusCode: 429, body: Data()) != .server(statusCode: 429))
    }

    @Test("Неизвестные 4xx не выдают себя за 5xx", arguments: [400, 418, 422])
    func unmatchedClientErrorsAreUnknown(statusCode: Int) {
        #expect(AppError(httpStatusCode: statusCode, body: Data()) == .unknown)
    }

    @Test("Транспортные сбои раскладываются по NetworkFailure", arguments: [
        (URLError.Code.notConnectedToInternet, AppError.network(.offline)),
        (.dataNotAllowed, .network(.offline)),
        (.timedOut, .network(.timedOut)),
        (.cannotConnectToHost, .network(.cannotConnect)),
        (.cannotFindHost, .network(.cannotConnect)),
        (.networkConnectionLost, .network(.cannotConnect)),
        (.badServerResponse, .network(.other)),
    ])
    func classifiesTransportErrors(code: URLError.Code, expected: AppError) {
        #expect(AppError(transportError: URLError(code)) == expected)
    }

    @Test("Отмена доезжает как .cancelled — через типизированный throws она не пролетает")
    func classifiesCancellation() {
        #expect(AppError(transportError: CancellationError()) == .cancelled)
        #expect(AppError(transportError: URLError(.cancelled)) == .cancelled)
    }

    @Test("Ошибка не из URLError не выдаёт себя за сетевую")
    func foreignErrorIsUnknown() {
        struct Foreign: Error {}

        #expect(AppError(transportError: Foreign()) == .unknown)
    }
}
