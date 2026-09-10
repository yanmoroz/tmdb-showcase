# VIPER-App

The demo app on UIKit + VIPER. Domain and data come from [SharedKit](../SharedKit/README.md); only presentation lives here.

- iOS 17+, Swift 6 language mode
- UIKit, `AppDelegate` + `SceneDelegate`
- Bundle ID `yanmoroz.tmdb.viper`, iPhone + iPad

## Differences from the Xcode template

- **No storyboards.** `Main.storyboard` and `LaunchScreen.storyboard` are removed together with `INFOPLIST_KEY_UIMainStoryboardFile` and `INFOPLIST_KEY_UILaunchStoryboardName`; `SceneDelegate` builds the window, and `Info.plist` carries an empty `UILaunchScreen` dictionary. The rule applies to all six `-App` projects.
- **No UI test target.** Nothing here is driven through XCUITest.
- **`Info.plist` is a real file** (`INFOPLIST_FILE`) alongside `GENERATE_INFOPLIST_FILE`, holding only what build settings cannot express: `TMDBAccessToken`, the scene manifest and `UILaunchScreen`.
- **`IPHONEOS_DEPLOYMENT_TARGET = 17.0`** on the project and repeated on the test target; the app target adds no override of its own.
- **`SWIFT_VERSION = 6.0`** on the app *and* the test target.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** with `SWIFT_APPROACHABLE_CONCURRENCY`. Presentation is main-actor isolated without annotations; leaving that actor is written out as `nonisolated`. `SharedKit` builds with its own flags.

## Token

`Config.xcconfig` → `Info.plist` → [AppConfig.swift](VIPER-App/AppConfig.swift). `Config.xcconfig` sits in the repository root and is the project's base configuration (`../Config.xcconfig`). `AppConfig` is the only place that touches `Bundle.main`; a missing token is a `fatalError`.

## Packages

| target | products |
| --- | --- |
| `VIPER-App` | `DomainKit`, `DataKit`, `PresentationKit`, `Nuke`, `NukeUI`, `YouTubeiOSPlayerHelper` |
| `VIPER-AppTests` | `DomainKit`, `DomainKitTestSupport`, `PresentationKit` |

`SharedKit` and `PresentationKit` are attached as local packages of the workspace, so opening `VIPER-App.xcodeproj` on its own will not resolve them.

## Structure

```
VIPER-App/
├── VIPER-App.xcodeproj
├── VIPER-App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift          window
│   ├── AppConfig.swift              reads the TMDB token from Info.plist
│   ├── Info.plist
│   └── Assets.xcassets
└── VIPER-AppTests/
```

## Running it

1. Set up `Config.xcconfig` in the repository root — see the [repository README](../README.md#setting-up)
2. Open `TMDB-Showcase.xcworkspace`
3. Scheme `VIPER-App`, an iOS 17+ simulator

## Status

Scaffolding only: build settings, the token path and the package links match [MVC-App](../MVC-App/README.md) and [MVP-App](../MVP-App/README.md). No screens yet — `SceneDelegate` installs a bare `UIViewController`.
