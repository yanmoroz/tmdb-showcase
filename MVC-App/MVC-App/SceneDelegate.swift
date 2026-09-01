//
//  SceneDelegate.swift
//  MVC-App
//
//  Created by Yan Moroz on 30.08.2026.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: makeRoot())
        window.makeKeyAndVisible()
        self.window = window
    }

    // Заглушка до появления экрана Movies.
    private func makeRoot() -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = "Movies"
        return viewController
    }
}
