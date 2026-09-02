//
//  SceneDelegate.swift
//  MVC-App
//
//  Created by Yan Moroz on 30.08.2026.
//

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
        window.rootViewController = isRunningTests
            ? UIViewController()
            : UINavigationController(rootViewController: makeRoot())
        window.makeKeyAndVisible()
        self.window = window
    }

    /// Unit tests build their own controllers, so the real stack is skipped:
    /// assembling it here reads the TMDB token, and a missing token aborts the
    /// host app before a single test can start.
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func makeRoot() -> UIViewController {
        let configuration = AppConfig.tmdb

        return MoviesViewController(
            fetchMovies: FetchMovies(repository: TMDBMoviesRepository(configuration: configuration)),
            fetchGenres: FetchGenres(repository: TMDBGenresRepository(configuration: configuration)),
            imageURLBuilder: TMDBImageURLBuilder(configuration: configuration)
        )
    }
}
