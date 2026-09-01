import Foundation

struct StubResponse: Sendable {
    var statusCode: Int = 200
    var body: Data = Data()
    /// Set to fail before any response is produced.
    var failure: URLError?

    static func json(_ body: Data, statusCode: Int = 200) -> StubResponse {
        StubResponse(statusCode: statusCode, body: body)
    }

    static func status(_ statusCode: Int, body: Data = Data()) -> StubResponse {
        StubResponse(statusCode: statusCode, body: body)
    }

    static func transport(_ code: URLError.Code) -> StubResponse {
        StubResponse(failure: URLError(code))
    }
}

/// A stubbed session plus the requests it saw.
struct StubSession {
    let session: URLSession
    fileprivate let id: String

    var recordedRequests: [URLRequest] { StubURLProtocol.requests(for: id) }
    var lastRequest: URLRequest? { recordedRequests.last }
}

/// Replaces the transport inside `URLSession` so tests exercise the real session,
/// URL building and header plumbing included.
///
/// `URLSession` instantiates protocol subclasses itself, so state has to be
/// static. It is keyed by a per-session header rather than shared globally —
/// otherwise two suites running in parallel overwrite each other's stub, and
/// `.serialized` would not help because it does not order separate suites.
final class StubURLProtocol: URLProtocol {
    private static let sessionHeader = "X-Stub-Session"

    private static let lock = NSLock()
    private nonisolated(unsafe) static var stubs: [String: StubResponse] = [:]
    private nonisolated(unsafe) static var log: [String: [URLRequest]] = [:]

    static func makeSession(_ response: StubResponse) -> StubSession {
        let id = UUID().uuidString
        lock.withLock {
            stubs[id] = response
            log[id] = []
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [sessionHeader: id]

        return StubSession(session: URLSession(configuration: configuration), id: id)
    }

    fileprivate static func requests(for id: String) -> [URLRequest] {
        lock.withLock { log[id] ?? [] }
    }

    private static func record(_ request: URLRequest) -> StubResponse? {
        guard let id = request.value(forHTTPHeaderField: sessionHeader) else { return nil }
        return lock.withLock {
            log[id, default: []].append(request)
            return stubs[id]
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = Self.record(request) else {
            // No session header means the per-session keying broke; failing loudly
            // beats silently serving another test's stub.
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        if let failure = stub.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }

        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: stub.statusCode,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "application/json"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
