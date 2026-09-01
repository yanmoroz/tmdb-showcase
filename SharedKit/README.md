# SharedKit

Локальный Swift Package с доменным слоем и слоем данных. Общий для всех шести реализаций приложения — Presentation-слой у каждой свой, всё остальное берётся отсюда без изменений.

| Таргет                | Назначение                                                       | Статус       |
| --------------------- | ---------------------------------------------------------------- | ------------ |
| `DomainKit`           | Сущности, `AppError`, протоколы репозиториев и use cases          | ✅ фича Movies |
| `DataKit`             | DTO, TMDB API-клиент, реализации репозиториев, маппинг ошибок      | ✅ фича Movies |
| `DomainKitTestSupport`| Фикстуры и стабы домена для тестов всех шести `-App`               | ✅            |

Swift 6 language mode, iOS 17+. `DomainKit` не импортирует ничего, кроме `Foundation`.

## Границы слоёв

Правила, на которые опираются все шесть Presentation-реализаций.

**Домен не знает про TMDB.** Пути картинок хранятся относительными строками (`posterPath`), полный URL собирает DataKit. Строки `sort_by`, путь окна трендов, ограничение TMDB на `page > 500` — тоже DataKit. В домене перечисления без `RawValue`.

**Домен stateless.** Пагинация — чистая функция `(query, page) -> Page<Movie>`. Накопленный список, текущая страница и флаг догрузки живут в Presenter / ViewModel / Interactor / Reducer. Это сознательный отказ от stateful-пагинатора: у TCA он создал бы второй источник состояния вне Store.

**Наружу только `async/await`.** Никакого Combine в `DomainKit`: он навязал бы одну модель реактивности всем шести архитектурам и не дружит со Swift 6 (паблишеры не `Sendable`). Запрет действует только на пакет — если MVVM-реализации нужен `@Published` поверх `async`-вызова, это её право и часть витрины различий.

**Классификация ошибок — обязанность DataKit.** Репозитории объявлены с типизированным `throws(AppError)`, поэтому `URLError`, `DecodingError` и прочий транспорт наружу не просачиваются физически. Отмену DataKit тоже обязан перехватить: через типизированный `throws` `CancellationError` не пролетает, для неё есть `AppError.cancelled`.

**Валидация ввода — в Presentation, но закреплена типом.** Обрезка пробелов и проверка «пустой поиск» намеренно дублируются в шести реализациях: это одна из осей сравнения архитектур, и живёт она рядом с debounce. Чтобы дублирование не стало шестью шансами забыть проверку, правило держит тип:

```swift
guard let text = SearchText(searchField.text ?? "") else {
    return showPopular()          // пустой ввод — не повод идти в сеть
}
load(query: .search(text))
```

`MoviesQuery.search` невозможно собрать из пробелов, так что компилятор не даст пропустить валидацию.

**Токен приходит снаружи.** `DataKit` не читает `Bundle.main`: пакет собирается и в `swift test`, где хост-бандла нет. Приложение конструирует `TMDBConfiguration(accessToken:)` и передаёт в репозитории. Используется v4 Read Access Token в заголовке `Authorization: Bearer`, не v3 `api_key` в query.

**Флаг «в избранном» не станет полем `Movie`.** Watchlist-состояние накладывается на `[Movie]` в Presentation по `Set<Movie.ID>` из будущего `WatchlistRepository`.

## Что где лежит

```
Sources/DomainKit/
├── Entities/       Movie, MovieDetails, Genre, Page<Item>,
│                   MoviesQuery (+ TrendingWindow, MovieSortOption), SearchText
├── Errors/         AppError (+ NetworkFailure)
├── Repositories/   MoviesRepository, GenresRepository
└── UseCases/       FetchMovies, FetchMovieDetails, FetchGenres
```

Use case — протокол с `callAsFunction` плюс struct-реализация. Presentation зависит от протокола (`any FetchMoviesUseCase`), поэтому в тестах презентеров и вьюмоделей подставляется стаб use case, а не фейковый репозиторий.

`Movie` и `MovieDetails` — разные типы, а не один с опциональными полями: в объединённом типе `runtime: Int?` означал бы одновременно «ещё не загружено» и «неизвестно».

```
Sources/DataKit/
├── Configuration/  TMDBConfiguration
├── Networking/     TMDBAPIClient, TMDBEndpoint, TMDBStatusResponse
├── DTOs/           PagedResponseDTO<Item>, MovieDTO, MovieDetailsDTO, GenreDTO
├── Mapping/        AppError+Classification, MoviesQuery+Endpoint, TMDBDate
├── Repositories/   TMDBMoviesRepository, TMDBGenresRepository
└── Images/         TMDBImageURLBuilder
```

Наружу публичны только `TMDBConfiguration`, две реализации репозиториев и `TMDBImageURLBuilder`. DTO, клиент и эндпоинты — `internal`: шесть приложений не должны знать формат TMDB, в этом и смысл границы.

Единственный `do/catch` пакета живёт в `TMDBAPIClient`; `AppError` рождается только там, через `init(httpStatusCode:body:)` и `init(transportError:)`. 403 разбирается по телу: пустое — гео-блокировка CDN, со `status_code` — отказ по токену. Иначе пользователю с битым токеном советовали бы включить VPN.

## Использование

В `-App` проекте пакет подключается как локальная зависимость, дальше `import DomainKit`. В тест-таргете — `import DomainKitTestSupport`:

```swift
let repository = MoviesRepositoryStub(
    moviesResult: .success(.fixture(items: Movie.fixtures(count: 20), totalPages: 5))
)
let sut = MoviesPresenter(fetchMovies: FetchMovies(repository: repository))
```

Стабы репозиториев и use cases — акторы с журналом вызовов (`moviesCalls`), фикстуры детерминированы: даты берутся от `Fixtures.referenceDate`, а не от текущего момента.

## Проверка

```bash
swift build --package-path SharedKit
```

```bash
swift test --package-path SharedKit
```

Прогон по умолчанию герметичен: транспорт подменяется через `URLProtocol`, поэтому тесты не требуют ни симулятора, ни токена, ни VPN.

Отдельно живёт контрактный ярус (`TMDBContractTests`) — пять запросов к настоящему TMDB. Фикстуры фиксируют вчерашний контракт и не заметят, если TMDB переименует поле или перестанет принимать строку `sort_by`; ловит это только живой запрос. Ярус включается наличием токена в окружении, иначе помечается skipped:

```bash
TMDB_ACCESS_TOKEN=$(grep TMDB_ACCESS_TOKEN Config.xcconfig | cut -d= -f2 | xargs) swift test --package-path SharedKit --filter TMDBContract
```

Из РФ/РБ для него нужен VPN — TMDB закрыт на уровне CDN.
