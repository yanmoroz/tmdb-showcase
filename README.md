# TMDB Showcase (iOS)

One application implemented six times, each on a different UI architecture.

## Architectures

| #   | Architecture                      | Status         |
| --- | --------------------------------- | -------------- |
| 1   | MVC                               | 🚧 in progress |
| 2   | MVP                               | ⏳ not started  |
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
- `.regionRestricted` is surfaced to the user as a toast
- Users in the affected regions need a VPN

## Repository layout

```
TMDB-Showcase.xcworkspace
├── SharedKit/                      (local Swift package)
│   └── Sources/
│       ├── DomainKit/              entities, use case and repository protocols, AppError
│       ├── DataKit/                DTOs, TMDB client, repository implementations, error mapping
│       └── DomainKitTestSupport/   domain fixtures and stubs for the -App test targets
├── MVC-App/
├── MVP-App/
├── MVVM-App/
├── VIPER-App/
├── VIP-App/
└── TCA-App/
```

The domain and data layers are shared by all six modules. The presentation layer — presenter, view model, interactor, reducer or store — is unique to each architecture and lives in its own `-App` project.

The boundaries between layers, binding on all six implementations, are written down in [SharedKit/README.md](SharedKit/README.md). Notes specific to one module live in its own README, for instance [MVC-App/README.md](MVC-App/README.md).

## Stack

- Swift 6 language mode, iOS 17+ (the floor for SwiftData)
- SPM
- TMDB REST API
- [Nuke](https://github.com/kean/Nuke) for loading and caching posters. The only third-party dependency: the domain and data layers import nothing but `Foundation`
- CI: GitLab CI / Fastlane (planned)

## Current status

`DomainKit` and `DataKit` are done for the Movies feature: entities, `AppError`, the protocols and their TMDB implementations, error classification, the image URL builder, plus fixtures and stubs for tests.

`MVC-App` has a working list of popular movies — a poster grid with pagination, error handling and pull-to-refresh. Next: search with debounce and the genre filter, then the details screen, then the remaining five architectures. Caching (SwiftData) and Watchlist come separately.

## Setting up

1. Sign up at [themoviedb.org](https://www.themoviedb.org/signup) and take the **API Read Access Token** (v4, a long JWT) from Settings → API. The short v3 API key will not do — requests go out with an `Authorization: Bearer` header
2. Copy `Config.xcconfig.example` to `Config.xcconfig` **in the repository root** and paste the token. The file is gitignored
3. From RU/BY, switch on a VPN to reach the API
