import Foundation
import Testing
import DataKit

extension Tag {
    /// Tests that reach the real TMDB.
    @Tag static var live: Self
}

enum LiveTMDB {
    static var accessToken: String? {
        let token = ProcessInfo.processInfo.environment["TMDB_ACCESS_TOKEN"]
        return token?.isEmpty == false ? token : nil
    }

    static var configuration: TMDBConfiguration {
        TMDBConfiguration(accessToken: accessToken ?? "")
    }
}

extension Trait where Self == ConditionTrait {
    /// Live tests need a token and, from RU/BY, a VPN. Without the environment
    /// variable they are skipped, so the default `swift test` stays hermetic.
    static var requiresTMDBAccess: Self {
        .enabled(
            if: LiveTMDB.accessToken != nil,
            "TMDB_ACCESS_TOKEN not set — live contract tests skipped"
        )
    }
}
