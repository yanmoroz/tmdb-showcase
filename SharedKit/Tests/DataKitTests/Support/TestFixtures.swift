import Foundation
import Testing
import DataKit

enum TestFixtures {
    static func data(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "json"),
            "Missing fixture \(name).json"
        )
        return try Data(contentsOf: url)
    }
}

extension TMDBConfiguration {
    static let test = TMDBConfiguration(accessToken: "test-token")
}
