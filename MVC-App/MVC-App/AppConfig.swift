import Foundation
import DataKit

/// Reads the TMDB token the build injected through `Config.xcconfig` → Info.plist.
///
/// Lives in the app rather than in DataKit: the package is also built by
/// `swift test`, where there is no host bundle to read.
enum AppConfig {
    static let tmdb = TMDBConfiguration(accessToken: accessToken)

    private static var accessToken: String {
        guard
            let token = Bundle.main.object(forInfoDictionaryKey: "TMDBAccessToken") as? String,
            !token.isEmpty,
            token != "YOUR_V4_READ_ACCESS_TOKEN_HERE"
        else {
            fatalError(
                """
                TMDB_ACCESS_TOKEN is not set. Copy Config.xcconfig.example to Config.xcconfig \
                and paste your v4 Read Access Token: themoviedb.org → Settings → API.
                """
            )
        }
        return token
    }
}
