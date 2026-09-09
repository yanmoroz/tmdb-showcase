import UIKit
import DomainKit
import DataKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = isRunningTests ? UIViewController() : makeRoot()
        window.makeKeyAndVisible()
        self.window = window
    }

    /// Unit tests build their own presenters, so the real stack is skipped:
    /// assembling it here reads the TMDB token, and a missing token aborts the
    /// host app before a single test can start.
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Opening the stores is this type's job; assembling screens is
    /// ``CompositionRoot``'s.
    private func makeRoot() -> UIViewController {
        let configuration = AppConfig.tmdb

        var movies: any MoviesRepository = TMDBMoviesRepository(configuration: configuration)
        var genres: any GenresRepository = TMDBGenresRepository(configuration: configuration)

        // Unlike the cache, a watchlist that will not open is not something to
        // run silently without: the stand-in reports the failure when the reader
        // actually tries to save.
        var watchlist: any WatchlistRepository = UnavailableWatchlistRepository()
        if let stored = SwiftDataWatchlistRepository() {
            watchlist = stored
        }

        // A store that will not open leaves the app running uncached rather than
        // not running at all.
        if let cache = MovieCache() {
            movies = CachingMoviesRepository(wrapping: movies, cache: cache)
            genres = CachingGenresRepository(wrapping: genres, cache: cache)
        }

        return CompositionRoot.makeTabBar(
            movies: movies,
            genres: genres,
            watchlist: watchlist,
            imageURLBuilder: TMDBImageURLBuilder(configuration: configuration)
        )
    }
}
