# MVP-App

The demo app on UIKit + MVP. Domain and data come from [SharedKit](../SharedKit/README.md); only presentation lives here.

- iOS 17+, Swift 6 language mode
- UIKit, `AppDelegate` + `SceneDelegate`
- Bundle ID `yanmoroz.tmdb.mvp`, iPhone + iPad

## Differences from the Xcode template

- **No storyboards.** `Main.storyboard` and `LaunchScreen.storyboard` are removed together with `INFOPLIST_KEY_UIMainStoryboardFile` and `INFOPLIST_KEY_UILaunchStoryboardName`; `SceneDelegate` builds the window, and `Info.plist` carries an empty `UILaunchScreen` dictionary. The rule applies to all six `-App` projects.
- **No UI test target.** Nothing here is driven through XCUITest.
- **`Info.plist` is a real file** (`INFOPLIST_FILE`) alongside `GENERATE_INFOPLIST_FILE`, holding only what build settings cannot express: `TMDBAccessToken`, the scene manifest and `UILaunchScreen`.
- **`IPHONEOS_DEPLOYMENT_TARGET = 17.0`** on the project and repeated on the test target; the app target adds no override of its own.
- **`SWIFT_VERSION = 6.0`** on the app *and* the test target.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** with `SWIFT_APPROACHABLE_CONCURRENCY`. Presentation is main-actor isolated without annotations; leaving that actor is written out as `nonisolated`. `SharedKit` builds with its own flags.

## Token

`Config.xcconfig` → `Info.plist` → [AppConfig.swift](MVP-App/AppConfig.swift). `Config.xcconfig` sits in the repository root and is the project's base configuration (`../Config.xcconfig`). `AppConfig` is the only place that touches `Bundle.main`; a missing token aborts the app at launch.

## Packages

| target | products |
| --- | --- |
| `MVP-App` | `DomainKit`, `DataKit`, `PresentationKit`, `Nuke`, `NukeUI`, `YouTubeiOSPlayerHelper` |
| `MVP-AppTests` | `DomainKit`, `DomainKitTestSupport`, `PresentationKit` |

`SharedKit` is attached as a local package of the workspace, so opening `MVP-App.xcodeproj` on its own will not resolve `DomainKit` and `DataKit`.

## Structure

```
MVP-App/
├── MVP-App.xcodeproj
├── MVP-App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift          window; opens the stores
│   ├── CompositionRoot.swift        assembles each screen
│   ├── AppConfig.swift              reads the TMDB token from Info.plist
│   ├── Movies/
│   │   ├── MoviesViewController.swift
│   │   ├── MoviesView.swift         what the presenter may ask of the screen
│   │   ├── MoviesPresenter.swift
│   │   ├── MoviesFeed.swift
│   │   ├── MoviesFilterViewController.swift
│   │   ├── MoviesFilterView.swift   plus FilterRow, a title and a tick
│   │   └── MoviesFilterPresenter.swift
│   ├── MovieDetails/
│   │   ├── MovieDetailsViewController.swift
│   │   ├── MovieDetailsView.swift
│   │   ├── MovieDetailsPresenter.swift
│   │   └── MovieDetailsModel.swift  the projection, seed plus what loaded
│   ├── Info.plist
│   └── Assets.xcassets
└── MVP-AppTests/
```

## Running it

1. Set up `Config.xcconfig` in the repository root — see the [repository README](../README.md#setting-up)
2. Open `TMDB-Showcase.xcworkspace`
3. Scheme `MVP-App`, an iOS 17+ simulator

## The presenter contract

`MoviesView` is a protocol of commands the controller obeys — `show(_:)`,
`showLoading()`, `showFailure(_:retry:)`, `showToast(_:)` — not a single
`render(state:)`, which is the shape the MVVM app will take. The presenter owns the
feed, the paging cursor, both inputs and the in-flight `Task`; the controller owns
the collection view and holds none of them.

Three points are worth knowing before reading the code:

- **`lastVisibleItem() -> Int?` is the one question among the commands.** After a page
  lands the presenter has to know whether the reader is already at the bottom:
  `willDisplay` fired for those cells while the request was in flight and found a load
  in progress, so without asking, the list stalls with nothing left to trigger the
  next page. That is where a passive view leaks.
- **Search availability is read from the keystroke, not the debounced value.** The
  controller reports every keystroke and the presenter both updates availability at
  once and debounces the query, so there is no window where the controls are live over
  a search about to start. MVC reads the search bar's text directly to get the same
  result.
- **Routing splits three ways.** The presenter decides *when* (`showFilter`,
  `showDetails`), `CompositionRoot` builds *what* through a factory closure, and the
  controller decides *how* it appears — `present` for the sheet, `push` for details. No
  router: that is the seam VIPER and TCA will differ on.
- **Assembly is three steps per screen**, and the third — `presenter.view = view` —
  fails silently, since `view` is `weak` and a missed assignment leaves a screen that
  builds, launches and never draws. `CompositionRoot` keeps that ritual in one method
  per screen and `CompositionRootTests` asserts each one happened. MVC-App needs
  neither.
- **The presenter joins display strings.** `MovieDetailsModel` carries one
  `metadata` field — "2026 · 2h 25m · ★ 7.9" — where MVC-App's model keeps year,
  runtime and rating apart and the controller joins them. Choosing a separator is not
  the view's decision.
- **The filter sheet sends whole sections, not row deltas.** MVC reloads the two rows
  whose tick moved; here the presenter re-sends the rows and the controller reloads the
  section. At twenty rows with `.none` animation the difference is invisible, and the
  presenter would otherwise have to track which row changed.

## Status

The movies list is done: poster grid, pagination, loading / empty / failure states,
pull-to-refresh, search with debounce, Popular/Trending, and bookmarking with an
optimistic mark that rolls back on a failed write. The genre and sort sheet is in,
owning the genre catalogue so nobody pays for that request unless it is opened.

The details screen is in: seeded from the `Movie` the list already holds, so the card
is never blank, with the loaded fields, the trailer and a bookmark arriving after. A
failure sits beside the card rather than over it — the view has no command that could
blank it.

The Watchlist tab is next; until then the app is a single navigation stack.

Each screen is tested twice over: a presenter suite that covers what
[MVC-App](../MVC-App/README.md)'s controller suites cover while standing up no `UIView`,
and a thin controller suite that the view honours its protocol against real UIKit.
