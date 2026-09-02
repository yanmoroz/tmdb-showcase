# MVC-App

The demo app on UIKit + MVC. Domain and data come from [SharedKit](../SharedKit/README.md); only presentation lives here.

- iOS 17+, Swift 6 language mode
- UIKit, `AppDelegate` + `SceneDelegate`
- Bundle ID `yanmoroz.tmdb.mvc`, iPhone + iPad

## Notable choices

**No storyboards, no xibs.** Everything is laid out in code.

- `Main.storyboard` and the `UISceneStoryboardFile` key in the scene manifest are gone; `SceneDelegate` builds the window and the root controller
- `LaunchScreen.storyboard` is replaced by an empty `UILaunchScreen` dictionary in `Info.plist`
- The rule applies to all six `-App` projects

**`Info.plist` is a real file** (`INFOPLIST_FILE`) alongside `GENERATE_INFOPLIST_FILE`. It holds only what build settings cannot express: `TMDBAccessToken`, the scene manifest and `UILaunchScreen`. Orientations and other `INFOPLIST_KEY_*` stay in build settings and are not duplicated in the file.

**Token path: `Config.xcconfig` → `Info.plist` → `AppConfig`.** `Config.xcconfig` sits in the repository root and is wired to the project as its base configuration (`../Config.xcconfig`). [AppConfig.swift](MVC-App/AppConfig.swift) reads the token and is the only place that touches `Bundle.main`. A missing token aborts the app at launch.

**`SceneDelegate` skips the real stack under tests.** Unit tests build their own controllers, and assembling the production stack would read the token — so a machine without the gitignored `Config.xcconfig` could not run a single test, even though none of them touch the network. The scene is detected as a test run through `XCTestConfigurationFilePath` in the environment.

**Open `TMDB-Showcase.xcworkspace`.** `SharedKit` is attached as a local package of the workspace; opening `MVC-App.xcodeproj` on its own will not resolve `DomainKit` and `DataKit`.

**`MainActor` by default** — `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` together with `SWIFT_APPROACHABLE_CONCURRENCY`. Presentation code is main-actor isolated without annotations, and leaving that actor is written out explicitly as `nonisolated`. This does not extend to `SharedKit`, which builds with its own flags.

## Structure

```
MVC-App/
├── MVC-App.xcodeproj
├── MVC-App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift          window and composition root
│   ├── AppConfig.swift              reads the TMDB token from Info.plist
│   ├── Movies/
│   │   ├── MoviesViewController.swift
│   │   └── MovieCell.swift
│   ├── Common/
│   │   ├── ToastView.swift
│   │   └── AppError+Message.swift
│   ├── Info.plist
│   └── Assets.xcassets
└── MVC-AppTests/
```

`Common/` is the seed of a shared UI package: its components take flat values and know nothing about the controller. Extraction is planned for the MVP stage, once it is clear what actually repeats.

## Running it

1. Set up `Config.xcconfig` in the repository root — see the [repository README](../README.md#setting-up)
2. Open `TMDB-Showcase.xcworkspace`
3. Scheme `MVC-App`, an iOS 17+ simulator

## What MVC looks like here

The reading is deliberately literal: `MoviesViewController` owns the accumulated list, the paging cursor and the in-flight `Task`, implements `UICollectionViewDataSource` and `UICollectionViewDelegate` itself, calls `FetchMovies` itself and classifies `AppError` itself. That is the Massive View Controller — the baseline the other five implementations will be compared against.

For the same reason it uses a classic `dataSource` rather than a diffable one: it leaves the state juggling on display, which is the point of the exercise.

Empty states — loading, no results, and failure with a retry button — are built on `contentUnavailableConfiguration` (iOS 17+) rather than a bespoke view. A hand-rolled one was written and then deleted: UIKit covers all three first-party, and `searchConfiguration` will come in useful for empty search results. The SwiftUI TCA version will use `ContentUnavailableView`, so none of this needs to move into a shared UI package.

The tests in `MVC-AppTests` measure what that costs. To check pagination you have to stand the whole view up, find the `UICollectionView` by walking the hierarchy, and poll for an in-flight `Task` that is never exposed. Under MVP the same checks become a call to a presenter method.

Because a retain cycle is easy to introduce here — the controller holds a `Task` and targets a `UIRefreshControl` — every test tracks whether its controller is deallocated afterwards, using the suite's `deinit` as teardown.

## Status

The list of popular movies is done: poster grid, pagination, loading / empty / failure states, a VPN toast on `.regionRestricted`, and pull-to-refresh. Next up is search with debounce and the genre filter, then the details screen.
