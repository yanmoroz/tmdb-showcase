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
│   ├── SceneDelegate.swift          window; opens the stores
│   ├── CompositionRoot.swift        assembles each module
│   ├── AppConfig.swift              reads the TMDB token from Info.plist
│   ├── Movies/
│   │   ├── MoviesViewController.swift
│   │   ├── MoviesView.swift         what the view is told and what it reports
│   │   ├── MoviesPresenter.swift
│   │   ├── MoviesInteractor.swift   its input and output, and the requests
│   │   ├── MoviesRouter.swift
│   │   └── MoviesFeed.swift
│   ├── Info.plist
│   └── Assets.xcassets
└── VIPER-AppTests/
```

## Running it

1. Set up `Config.xcconfig` in the repository root — see the [repository README](../README.md#setting-up)
2. Open `TMDB-Showcase.xcworkspace`
3. Scheme `VIPER-App`, an iOS 17+ simulator

## The module

A screen is four objects behind five protocols. The controller knows the presenter only as `MoviesViewOutput`; the presenter talks to `MoviesView`, `MoviesInteractorInput` and `MoviesRouterInput`; the interactor answers through `MoviesInteractorOutput`. The view owns the presenter, which owns the interactor and the router.

Worth knowing before reading the code:

- **Three back-references are `weak` and assigned after construction** — `presenter.view`, `interactor.output`, `router.viewController`. Each one forgotten leaves a module that builds and silently does nothing, so `CompositionRoot` assigns all three in one place and `CompositionRootTests` checks each. MVP-App has one such reference.
- **Loading has two sources of truth.** The interactor owns the request; the presenter keeps a flag for the overlay and for pagination. MVP-App keeps the `Task` inside `Activity.loading`, which makes "loading with nothing in flight" unrepresentable; here only `loadPage`'s contract prevents it — starting a load abandons the one in flight, whose result is never reported, and every other load reports exactly once. The presenter suite pins the flag's half, the interactor suite the request's.
- **The presenter suite is synchronous.** With the interactor faked, a test calls the output methods itself; only the search debounce is still waited for.
- **The view no longer routes.** `showFilter` and `showDetails` moved from the view protocol to `MoviesRouterInput`, so the controller is handed no destinations.
- **`lastVisibleItem() -> Int?` is still the one question among the commands**, for the reason [MVP-App](../MVP-App/README.md#the-presenter-contract) gives.

## Status

The movies list is in: poster grid, pagination, loading / empty / failure states, pull-to-refresh, search with debounce, Popular/Trending, and bookmarking with an optimistic mark that rolls back on a failed write. The filter sheet and the details screen come next; until they land, the router's two routes do nothing.
