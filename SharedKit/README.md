# SharedKit

A local Swift package holding the domain and data layers. Shared by all six implementations of the app — each has its own presentation layer, everything else is taken from here unchanged.

| Target                 | Purpose                                                        | Status          |
| ---------------------- | -------------------------------------------------------------- | --------------- |
| `DomainKit`            | Entities, `AppError`, repository and use case protocols          | ✅ Movies feature |
| `DataKit`              | DTOs, TMDB API client, repository implementations, error mapping, SwiftData cache | ✅ Movies feature |
| `DomainKitTestSupport` | Domain fixtures and stubs for all six `-App` test targets        | ✅               |

Swift 6 language mode, iOS 17+. `DomainKit` imports nothing but `Foundation`.

## Layer boundaries

The rules all six presentation implementations rest on.

**The domain knows nothing about TMDB.** Image paths are stored as relative strings (`posterPath`) and DataKit assembles the full URL behind `MovieImageURLBuilder` — the size vocabulary (`w342`, `w780`) is TMDB's wire detail and stops at that protocol, so no screen picks a CDN size. The `sort_by` strings, the trending window path and TMDB's `page > 500` limit are DataKit's too. Domain enums carry no `RawValue`.

**The domain is stateless.** Pagination is a pure `(query, page) -> Page<Movie>`. The accumulated list, the current page and the loading flag live in the presenter, view model, interactor or reducer. This is a deliberate refusal of a stateful paginator: in TCA it would create a second source of state outside the store.

**Only `async/await` crosses the boundary.** No Combine in `DomainKit`: it would impose one reactivity model on all six architectures and does not sit well with Swift 6, where publishers are not `Sendable`. The ban covers the package alone — if an MVVM implementation wants `@Published` on top of an `async` call, that is its right and part of what the showcase compares.

**Classifying errors is DataKit's job.** The repositories are declared with typed `throws(AppError)`, so `URLError`, `DecodingError` and the rest of the transport physically cannot leak out. Cancellation has to be caught there too: `CancellationError` does not travel through typed `throws`, which is why `AppError.cancelled` exists.

**Input validation lives in presentation, pinned by a type.** Trimming whitespace and rejecting a blank search are duplicated across the six implementations on purpose: it is one of the axes being compared, and it belongs next to the debounce. So the duplication does not become six chances to forget the check, the rule is held by a type:

```swift
guard let text = SearchText(searchField.text ?? "") else {
    return showPopular()          // blank input is no reason to hit the network
}
load(query: .search(text))
```

`MoviesQuery.search` cannot be built out of whitespace, so the compiler will not let the validation be skipped.

**The token comes from outside.** `DataKit` never reads `Bundle.main`: the package also builds under `swift test`, where there is no host bundle. The app constructs `TMDBConfiguration(accessToken:)` and passes it to the repositories. A v4 Read Access Token goes in an `Authorization: Bearer` header — not a v3 `api_key` in the query.

**Caching is a decorator, and the two resources cache differently.**
`CachingMoviesRepository` and `CachingGenresRepository` wrap the TMDB ones and
implement the same domain protocols, so nothing above the repository seam knows
they exist. Feed pages are **network first**: a feed changes hourly, so the cache
answers only when the request never left the device — `AppError.allowsCacheFallback`
admits `.network(_)` and nothing else, which is why a geo-block still reaches the
user with its VPN prompt and a cancelled search stays cancelled. Only page one is
written; later pages would mean reconciling a partial feed against a cursor that
only presentation understands.

The genre catalogue is **read-through within a freshness window** instead. Nineteen
rows that change once a year do not justify a request every time the filter opens,
and a fallback-only cache would still make that screen fetch and show a loading row
on every open. The window decides whether the network is skipped, never whether old
rows are usable: once a request has failed, a stale catalogue still beats an empty
filter screen. A cached *empty* catalogue is never treated as fresh, so one blank
answer cannot hide the real list for a week.

Nothing records **where** an answer came from. Carrying provenance would mean
`Page<Movie>` and `[Genre]` growing a field that all six presentation layers must
then interpret — the same objection that ruled out stale-while-revalidate — to
report something the reader cannot act on. The visible cost is that offline
pull-to-refresh looks like it succeeded.

**The "in watchlist" flag will not become a field on `Movie`.** Watchlist state is overlaid onto `[Movie]` in presentation through a `Set<Movie.ID>` from the future `WatchlistRepository`.

## What lives where

```
Sources/DomainKit/
├── Entities/       Movie, MovieDetails, Genre, Page<Item>,
│                   MoviesQuery (+ TrendingWindow, MovieSortOption), SearchText
├── Errors/         AppError (+ NetworkFailure)
├── Images/         MovieImageURLBuilder
├── Repositories/   MoviesRepository, GenresRepository
└── UseCases/       FetchMovies, FetchMovieDetails, FetchGenres
```

A use case is a protocol with `callAsFunction` plus a struct implementation. Presentation depends on the protocol (`any FetchMoviesUseCase`), so presenter and view model tests substitute a use case stub rather than a fake repository.

`Movie` and `MovieDetails` are separate types rather than one type with optional fields: in a merged type `runtime: Int?` would mean both "not loaded yet" and "unknown" at once.

```
Sources/DataKit/
├── Configuration/  TMDBConfiguration
├── Networking/     TMDBAPIClient, TMDBEndpoint, TMDBStatusResponse, JSONDecoder+TMDB
├── DTOs/           PagedResponseDTO<Item>, MovieDTO, MovieDetailsDTO, GenreDTO
├── Mapping/        AppError+Classification, MoviesQuery+Endpoint, TMDBDate,
│                   Optional+NonEmpty
├── Persistence/    MovieCache, MovieCacheStore, GenreCacheStore, MoviesQueryKey,
│                   MovieCacheSchema, MovieCacheContainer, CachePolicy
├── Repositories/   TMDBMoviesRepository, TMDBGenresRepository,
│                   CachingMoviesRepository, CachingGenresRepository
└── Images/         TMDBImageURLBuilder
```

Only `TMDBConfiguration`, the four repository implementations, `MovieCache` and `TMDBImageURLBuilder` are public, and presentation names none of them: it takes `any MoviesRepository`, `any MovieImageURLBuilder` and the rest, so `import DataKit` appears in the composition root of an `-App` and nowhere else. The `@Model` types, the stores and `MoviesQueryKey` are `internal` — the cache's shape on disk is nobody else's business. DTOs, the client and the endpoints are `internal`: the six apps have no business knowing TMDB's wire format, which is the whole point of the boundary.

The package's single `do/catch` lives in `TMDBAPIClient`, and `AppError` is born only there, through `init(httpStatusCode:body:)` and `init(transportError:)`. A 403 is told apart by its body: empty means the CDN geo-block, one carrying `status_code` means TMDB rejected the token. Otherwise someone with a broken token would be advised to switch on a VPN.

## Using it

In an `-App` project the package is added as a local dependency, then `import DomainKit`. In a test target, `import DomainKitTestSupport`.

Presentation tests stub the use case, since that is what presentation depends on:

```swift
let fetchMovies = FetchMoviesStub(
    result: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 5))
)
```

Domain tests go one level lower and stub the repository instead:

```swift
let repository = MoviesRepositoryStub(
    moviesResult: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 5))
)
```

Repository and use case stubs are actors with a call log (`moviesCalls`, `calls`). Fixtures are deterministic: dates come from `Fixtures.referenceDate`, never from the current moment.

## Verifying

```bash
swift build --package-path SharedKit
```

```bash
swift test --package-path SharedKit
```

The default run is hermetic: the transport is swapped out through `URLProtocol`, so the tests need no simulator, no token and no VPN.

A contract tier (`TMDBContractTests`) lives alongside it — five requests against the real TMDB. Fixtures pin yesterday's contract and will not notice if TMDB renames a field or stops accepting a `sort_by` string; only a live request catches that. The tier switches on when a token is present in the environment, and is reported as skipped otherwise:

```bash
TMDB_ACCESS_TOKEN="$(sed -n 's/^TMDB_ACCESS_TOKEN[[:space:]]*=[[:space:]]*//p' Config.xcconfig | tr -d '[:space:]')" swift test --package-path SharedKit --filter TMDBContract
```

From RU/BY it needs a VPN — TMDB is blocked at the CDN.
