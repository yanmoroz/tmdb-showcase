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
│   ├── SceneDelegate.swift              window; opens the stores
│   ├── CompositionRoot.swift            assembles the root module
│   ├── AppConfig.swift                  reads the TMDB token from Info.plist
│   ├── Movies/
│   │   ├── MoviesViewController.swift
│   │   ├── MoviesView.swift             what the view is told and what it reports
│   │   ├── MoviesPresenter.swift
│   │   ├── MoviesInteractor.swift       its input and output, and the requests
│   │   ├── MoviesRouter.swift           builds and presents what the list opens
│   │   └── MoviesFeed.swift
│   ├── MoviesFilter/
│   │   ├── MoviesFilterViewController.swift
│   │   ├── MoviesFilterView.swift
│   │   ├── MoviesFilterPresenter.swift
│   │   ├── MoviesFilterInteractor.swift
│   │   └── MoviesFilterRouter.swift     assembles the sheet; its output protocol
│   ├── MovieDetails/
│   │   ├── MovieDetailsViewController.swift
│   │   ├── MovieDetailsView.swift
│   │   ├── MovieDetailsPresenter.swift
│   │   ├── MovieDetailsInteractor.swift
│   │   └── MovieDetailsRouter.swift     assembles the card; nothing to route
│   ├── Info.plist
│   └── Assets.xcassets
└── VIPER-AppTests/
```

## Running it

1. Set up `Config.xcconfig` in the repository root — see the [repository README](../README.md#setting-up)
2. Open `TMDB-Showcase.xcworkspace`
3. Scheme `VIPER-App`, an iOS 17+ simulator

## The module

A screen is four objects behind five protocols. The controller knows the presenter only as its `…ViewOutput`; the presenter talks to the view, the interactor's input and the router; the interactor answers through its output. The view owns the presenter, which owns the interactor and the router. A screen that leads nowhere has no router: the details card is three objects behind four protocols, and `MovieDetailsRouter` is only its `makeModule`. Each module has a folder of its own, where MVP-App keeps the filter sheet inside `Movies/`.

Worth knowing before reading the code:

- **Up to three back-references are `weak` and assigned after construction** — `presenter.view`, `interactor.output`, `router.viewController`. Each one forgotten leaves a module that builds and silently does nothing, so every module is assembled in exactly one place — `CompositionRoot` for the root, the module's own `makeModule` otherwise — and a test checks each. MVP-App has one such reference.
- **Loading has two sources of truth.** The interactor owns the request; the presenter keeps a flag for the overlay and for pagination. MVP-App keeps the `Task` inside `Activity.loading`, which makes "loading with nothing in flight" unrepresentable; here only `loadPage`'s contract prevents it — starting a load abandons the one in flight, whose result is never reported, and every other load reports exactly once. The presenter suite pins the flag's half, the interactor suite the request's. The filter sheet and the details card repeat the arrangement.
- **Routers build what they open.** `MoviesRouter` calls the sheet's and the card's `makeModule` and presents or pushes the result, so it holds the movies, genres and watchlist repositories and the image URL builder for that alone: every dependency of every screen it opens passes through it. In MVP-App the same dependencies sat in `CompositionRoot` closures the controller only called.
- **A module reports back through a protocol.** The sheet hands its selection to `MoviesFilterModuleOutput`, which the movies presenter implements. It is `weak` but passed through `init`, so unlike the three above it cannot be forgotten.
- **The presenter suites are synchronous.** With the interactor faked, a test calls the output methods itself; only the movies search debounce is still waited for.
- **Views neither route nor dismiss.** `showFilter`, `showDetails` and the sheet's `dismiss` moved from the view protocols to the routers.
- **`lastVisibleItem() -> Int?` is still the one question among the commands**, for the reason [MVP-App](../MVP-App/README.md#the-presenter-contract) gives.

## Status

The movies list is in: poster grid, pagination, loading / empty / failure states, pull-to-refresh, search with debounce, Popular/Trending, and bookmarking with an optimistic mark that rolls back on a failed write. The genre and sort sheet is in, owning the genre catalogue so nobody pays for that request unless it is opened.

The details card is in: seeded from the `Movie` the list already holds, so it is never blank, with the loaded fields, the trailer and a bookmark arriving after. A failure sits beside the card rather than over it. Next: the Watchlist tab.
