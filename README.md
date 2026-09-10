# TMDB Showcase (iOS)

One application implemented six times, each on a different UI architecture.

## Architectures

| #   | Architecture                      | Status         |
| --- | --------------------------------- | -------------- |
| 1   | MVC                               | ✅ done         |
| 2   | MVP                               | ✅ done         |
| 3   | MVVM                              | ⏳ not started  |
| 4   | VIPER                             | ⏳ not started  |
| 5   | VIP (Clean Swift)                 | ⏳ not started  |
| 6   | TCA (The Composable Architecture) | ⏳ not started  |

## The idea

The same app, six times over — identical domain layer and identical API, a different presentation layer each time.

## Demo app: Movie Catalog

A movie catalogue built on the [TMDB API](https://developer.themoviedb.org/docs/getting-started).

### Features

**1. Movies**

- Popular and trending movies with pagination
- Search with debounce
- Genre filter
- Push to the details screen

**2. Watchlist / Favorites**

- Local storage of favourites
- The "in watchlist" flag reflected on the Movies screen

### Navigation

- Tab bar: Movies / Watchlist
- Push to Detail from both tabs
- Modal sort and filter screen

### Error handling

TMDB is geo-blocked at the CDN level for RU/BY.

- HTTP failures are classified into the single domain error `AppError` — a 401 carries a structured TMDB body, the CDN block answers 403 with none
- `.regionRestricted` reaches the reader as the screen's failure state, with no Retry: without a VPN a retry returns the same 403. It becomes a toast only when there is already loaded content a failure must not replace
- Users in the affected regions need a VPN

## Repository layout

```
TMDB-Showcase.xcworkspace
├── SharedKit/                      (local Swift package)
│   └── Sources/
│       ├── DomainKit/              entities, use case and repository protocols, AppError
│       ├── DataKit/                DTOs, TMDB client, repository implementations, error mapping, SwiftData cache
│       └── DomainKitTestSupport/   domain fixtures and stubs for the -App test targets
├── PresentationKit/                (local Swift package, iOS only)
│   └── Sources/                    the cell, the grid, the toast, the formatting and the view state the UIKit apps share
├── MVC-App/
├── MVP-App/
├── VIPER-App/
├── MVVM-App/                       ┐
├── VIP-App/                        ├ planned, not in the repository yet
└── TCA-App/                        ┘
```

The domain and data layers are shared by all six modules, and the five UIKit ones also share their views through `PresentationKit` — a poster cell is not an architectural choice. The presentation layer — presenter, view model, interactor, reducer or store — is unique to each architecture and lives in its own `-App` project.

The boundaries between layers, binding on all six implementations, are written down in [SharedKit/README.md](SharedKit/README.md). Notes specific to one module live in its own README, for instance [MVC-App/README.md](MVC-App/README.md).

## Language

Everything in this repository is in English: source, comments, README files, test
names, and user-facing strings. The project started out mixing English code with
Russian test names and UI copy; that is gone, and English is now the single rule.

The app is deliberately not localised. There is one language and it is hard-coded,
so `AppError.message`, screen titles and empty-state copy are plain literals rather
than lookups in `Localizable.strings`. Adding localisation would mean six parallel
string catalogues for no gain on the thing this repository is actually comparing.

## Stack

- Swift 6 language mode, iOS 17+ (the floor for SwiftData)
- SPM
- TMDB REST API
- [Nuke](https://github.com/kean/Nuke) for loading and caching posters — through `PresentationKit`'s cell on the grids, and directly in each details screen
- [youtube-ios-player-helper](https://github.com/youtube/youtube-ios-player-helper) for the trailer on the details screen — TMDB returns a YouTube id, not a playable URL
- Those two are the only third-party dependencies, and both stop at presentation: the domain and data layers import nothing but `Foundation`
- CI: GitLab CI / Fastlane (planned)

## Current status

`DomainKit` and `DataKit` are done for both features: entities, `AppError`, the protocols and their TMDB implementations, error classification, the image URL builder, a SwiftData cache for pages and details, a second store for the watchlist, plus fixtures and stubs for tests.

`MVC-App` has all four screens: a poster grid with pagination, error handling and pull-to-refresh, popular and trending feeds, search with debounce, a modal screen for the genre filter and sort order, and a details screen with its trailer. It reads through a SwiftData cache, so a warm launch shows films before the network answers and keeps working without one. The Watchlist tab is in too, on its own store.

`MVP-App` now does the same four screens over the same `SharedKit`, so the two can be
compared directly. Each screen is a presenter owning the state and a passive view
obeying a protocol of commands, and the views themselves are shared through
`PresentationKit` — a poster cell is not an architectural choice. What that buys shows
up in the tests: MVP's presenter suites cover what MVC's controller suites cover while
standing up no `UIView` at all. Next: the remaining four architectures.

## Setting up

1. Sign up at [themoviedb.org](https://www.themoviedb.org/signup) and take the **API Read Access Token** (v4, a long JWT) from Settings → API. The short v3 API key will not do — requests go out with an `Authorization: Bearer` header
2. Copy `Config.xcconfig.example` to `Config.xcconfig` **in the repository root** and paste the token. The file is gitignored
3. From RU/BY, switch on a VPN to reach the API
