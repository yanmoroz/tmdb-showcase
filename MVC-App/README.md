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
│   │   ├── MoviesFilterViewController.swift
│   │   ├── MoviesFilter.swift
│   │   └── MovieCell.swift
│   ├── Common/
│   │   ├── Debouncer.swift
│   │   ├── ToastView.swift
│   │   ├── MovieSortOption+Title.swift
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

That state is still modelled on two axes rather than left as a heap of parallel variables: `Feed` is what we have (movies plus the paging cursor), `Activity` is what we are doing (`idle` / `loading(Task)` / `failed`). The in-flight task lives inside the `.loading` case, so "loading with nothing in flight" and "a request nobody waits on" are not expressible, and cancellation is read from `Task.isCancelled` rather than a generation counter.

This is deliberately orthogonal to the pattern. Modelling state so illegal combinations do not compile is something a competent MVC does too — moving the same variables into a presenter would reproduce the same bugs one layer up. Keeping it here means the comparison with the other five measures the architecture, not how carelessly the first implementation was written.

Empty states — loading, no results, and failure with a retry button — are built on `contentUnavailableConfiguration` (iOS 17+) rather than a bespoke view. A hand-rolled one was written and then deleted: UIKit covers all three first-party, and `searchConfiguration` will come in useful for empty search results. The SwiftUI TCA version will use `ContentUnavailableView`, so none of this needs to move into a shared UI package.

Search reuses two things from the domain rather than reimplementing them. `SearchText`'s failable initialiser *is* the "blank input is no reason to hit the network" rule — `nil` means fall back to whatever the filter says, and no whitespace trimming is written here. And because `MoviesQuery` is `Hashable`, deleting typed text back to what is already on screen compares equal and reloads nothing.

Debouncing lives in `Common/Debouncer.swift`, which cancels the previous piece of work inside `schedule`. Its interval is injected, so tests pass `.zero` and drain the main actor instead of waiting on wall-clock.

The filter turns the screen's single input into two independent ones. `MoviesFilter` is what the user configured; the search text is what they typed; the query is derived from both, and `didSet` on each input is what keeps them from drifting. That is why a filter survives a search: clear the field after filtering by Horror and Horror comes back, not popular.

The genre catalogue belongs to the filter screen rather than this one — nobody pays for that request unless the filter is opened, and a second loading state never layers over the movie list. `MoviesViewController` knows only the chosen `Genre.ID`. That screen models its own load on the same axis, with the task inside its `.loading` case.

Routing is the plainest form available: the controller presents the modal itself and takes the result through a closure passed to the init. No coordinator, deliberately — that is the seam VIPER's Router and TCA's navigation state will differ on.

Search and filter cannot combine, because TMDB's search endpoint accepts neither `with_genres` nor `sort_by` and `MoviesQuery` makes the combination unrepresentable. In the UI that shows up as the filter button being disabled while a search is active, rather than applying a filter silently discarding typed text.

The tests in `MVC-AppTests` measure what that costs. To check pagination you have to stand the whole view up, find the `UICollectionView` by walking the hierarchy, and poll for an in-flight `Task` that is never exposed. Under MVP the same checks become a call to a presenter method.

Because a retain cycle is easy to introduce here — the controller holds a `Task` and targets a `UIRefreshControl` — every test tracks whether its controller is deallocated afterwards, using the suite's `deinit` as teardown.

## Status

The list of popular movies is done: poster grid, pagination, loading / empty / failure states, a VPN toast on `.regionRestricted`, and pull-to-refresh. Search with debounce is done too — typing switches the query, clearing returns to whatever the filter says, and empty results get the first-party search state. The genre filter and sorting are in, behind a modal screen that owns the genre catalogue. Next up is the details screen.
