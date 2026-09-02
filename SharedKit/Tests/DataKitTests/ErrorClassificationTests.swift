import Testing
import Foundation
import DomainKit
@testable import DataKit

@Suite("Error classification")
struct ErrorClassificationTests {
    @Test("Status codes map onto domain errors", arguments: [
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

    @Test("403 with no body is the CDN region block")
    func emptyForbiddenIsRegionRestricted() {
        #expect(AppError(httpStatusCode: 403, body: Data()) == .regionRestricted)
    }

    @Test("403 with a TMDB body is a token refusal, not a region block")
    func structuredForbiddenIsUnauthorized() throws {
        let body = try TestFixtures.data("error_401")

        // Otherwise someone with a broken token would be told to switch on a VPN.
        #expect(AppError(httpStatusCode: 403, body: body) == .unauthorized)
    }

    @Test("404 and 429 do not fall into .server")
    func dedicatedCasesWinOverServer() {
        #expect(AppError(httpStatusCode: 404, body: Data()) != .server(statusCode: 404))
        #expect(AppError(httpStatusCode: 429, body: Data()) != .server(statusCode: 429))
    }

    @Test("Unknown 4xx do not pass themselves off as 5xx", arguments: [400, 418, 422])
    func unmatchedClientErrorsAreUnknown(statusCode: Int) {
        #expect(AppError(httpStatusCode: statusCode, body: Data()) == .unknown)
    }

    @Test("Transport failures map onto NetworkFailure", arguments: [
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

    @Test("Cancellation arrives as .cancelled — typed throws does not let it slip past")
    func classifiesCancellation() {
        #expect(AppError(transportError: CancellationError()) == .cancelled)
        #expect(AppError(transportError: URLError(.cancelled)) == .cancelled)
    }

    @Test("A non-URLError does not pass itself off as a network failure")
    func foreignErrorIsUnknown() {
        struct Foreign: Error {}

        #expect(AppError(transportError: Foreign()) == .unknown)
    }
}
