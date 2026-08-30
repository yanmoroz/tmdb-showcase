// DataKit

import Foundation

public enum AppConfig {
    public static var tmdbAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String,
              !key.isEmpty,
              key != "YOUR_API_KEY_HERE" else {
            fatalError("TMDB_API_KEY не задан. Скопируйте Config.xcconfig.example в Config.xcconfig и подставьте ключ.")
        }
        return key
    }
}
