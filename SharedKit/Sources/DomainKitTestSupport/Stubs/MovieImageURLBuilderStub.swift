import Foundation
import DomainKit

public struct MovieImageURLBuilderStub: MovieImageURLBuilder {
    private let baseURL: URL

    public init(baseURL: URL = URL(string: "https://images.test")!) {
        self.baseURL = baseURL
    }

    public func posterURL(path: String?) -> URL? {
        url(path: path)
    }

    public func backdropURL(path: String?) -> URL? {
        url(path: path)
    }

    /// Nil for a missing path, like the real one: presentation hides an image
    /// view on nil, and a stub that always answered would hide the bug.
    private func url(path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return baseURL.appending(path: path)
    }
}
