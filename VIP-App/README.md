# VIP-App

The demo app on UIKit + VIP (Clean Swift). Domain and data come from [SharedKit](../SharedKit/README.md); only presentation lives here.

- iOS 17+, Swift 6 language mode
- UIKit, `AppDelegate` + `SceneDelegate`
- Bundle ID `yanmoroz.tmdb.vip`, iPhone + iPad

## Differences from the Xcode template

- **No storyboards.** `Main.storyboard` and `LaunchScreen.storyboard` are removed together with `INFOPLIST_KEY_UIMainStoryboardFile` and `INFOPLIST_KEY_UILaunchStoryboardName`; `SceneDelegate` builds the window, and `Info.plist` carries an empty `UILaunchScreen` dictionary. The rule applies to all six `-App` projects.
- **No UI test target.** Nothing here is driven through XCUITest.
- **`Info.plist` is a real file** (`INFOPLIST_FILE`) alongside `GENERATE_INFOPLIST_FILE`, holding only what build settings cannot express: `TMDBAccessToken`, the scene manifest and `UILaunchScreen`.
- **`IPHONEOS_DEPLOYMENT_TARGET = 17.0`** on the project and repeated on the test target; the app target adds no override of its own.
- **`SWIFT_VERSION = 6.0`** on the app *and* the test target.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** with `SWIFT_APPROACHABLE_CONCURRENCY`. Presentation is main-actor isolated without annotations; leaving that actor is written out as `nonisolated`. `SharedKit` builds with its own flags.

## Token

`Config.xcconfig` → `Info.plist` → [AppConfig.swift](VIP-App/AppConfig.swift). `Config.xcconfig` sits in the repository root and is the project's base configuration (`../Config.xcconfig`). `AppConfig` is the only place that touches `Bundle.main`; a missing token is a `fatalError`.

## Packages

| target | products |
| --- | --- |
| `VIP-App` | `DomainKit`, `DataKit`, `PresentationKit`, `Nuke`, `NukeUI`, `YouTubeiOSPlayerHelper` |
| `VIP-AppTests` | `DomainKit`, `DomainKitTestSupport`, `PresentationKit` |

`SharedKit` and `PresentationKit` are attached as local packages of the workspace, so opening `VIP-App.xcodeproj` on its own will not resolve them.

## Structure

```
VIP-App/
├── VIP-App.xcodeproj
├── VIP-App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift              window; opens the stores
│   ├── CompositionRoot.swift            assembles each scene
│   ├── AppConfig.swift                  reads the TMDB token from Info.plist
│   ├── Movies/
│   │   ├── MoviesViewController.swift   and its display logic
│   │   ├── MoviesInteractor.swift       and its business logic and data store
│   │   ├── MoviesPresenter.swift        and its presentation logic
│   │   ├── MoviesRouter.swift           and its routing logic and data passing
│   │   ├── MoviesModels.swift           every request, response and view model
│   │   └── MoviesFeed.swift
│   ├── Info.plist
│   └── Assets.xcassets
└── VIP-AppTests/
```

## Running it

1. Set up `Config.xcconfig` in the repository root — see the [repository README](../README.md#setting-up)
2. Open `TMDB-Showcase.xcworkspace`
3. Scheme `VIP-App`, an iOS 17+ simulator

## The scene

A screen is four objects behind six protocols, and every call between them carries a type from `MoviesModels`. The flow goes one way: the controller sends a request through `MoviesBusinessLogic`, the interactor hands a response through `MoviesPresentationLogic`, the presenter hands a view model through `MoviesDisplayLogic`. The controller owns the interactor and the router; the interactor owns the presenter; the router holds the interactor as its `MoviesDataStore`.

Worth knowing before reading the code:

- **Two back-references are `weak` and assigned after construction** — `presenter.viewController`, `router.viewController`. Everything else goes through `init`. `CompositionRoot` assigns both in one place and `CompositionRootTests` checks each. VIPER-App has three per module, MVP-App one.
- **The interactor owns state and the request together**, so `Activity.loading` carries its `Task` as in MVP-App. VIPER-App's `loadPage` contract has no counterpart here.
- **The presenter stores nothing** but the way back to the view, and its suite is synchronous. Pagination, search, filter and rollback are tested in the interactor suite, next to the use cases they await, which polls as MVP-App's presenter suite does.
- **The interactor is the data store.** `filter` and `selectedMovie` sit in `MoviesDataStore` for the router to read.
- **Nothing asks what is on screen.** `reloadData` re-displays the visible cells at the next layout and `willDisplay` sends each of them again, which keeps a reader already at the bottom paginating. There is no `lastVisibleItem()`.
- **The controller holds its router as `MoviesRoutingLogic` only.** `MoviesDataPassing` is for other routers.
- **Models are grouped by role** — `MoviesModels.Request`, `.Response`, `.ViewModel` — not by use case as in the Clean Swift templates. `start` alone leads to five responses, and `Feed` is reported for seven different causes.

## Status

The movies list is in: poster grid, pagination, loading / empty / failure states, pull-to-refresh, search with debounce, Popular/Trending, and bookmarking with an optimistic mark that rolls back on a failed write. The filter sheet and the details screen come next; until they land, the router's two routes do nothing.
