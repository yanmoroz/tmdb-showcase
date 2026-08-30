# TMDB Showcase (iOS)

Репозиторий с 6 реализациями одного и того же приложения на разных UI-архитектурах.

## Архитектуры

| #   | Архитектура                       | Статус          |
| --- | --------------------------------- | --------------- |
| 1   | MVC                               | 🚧 в разработке |
| 2   | MVP                               | ⏳ не начато    |
| 3   | MVVM                              | ⏳ не начато    |
| 4   | VIPER                             | ⏳ не начато    |
| 5   | VIP (Clean Swift)                 | ⏳ не начато    |
| 6   | TCA (The Composable Architecture) | ⏳ не начато    |

## Идея

Одно и то же приложение реализуется 6 раз — с одинаковым доменным слоем и одинаковым API, но разным Presentation-слоем.

## Демо-приложение: Movie Catalog

Каталог фильмов на основе [TMDB API](https://developer.themoviedb.org/docs/getting-started).

### Фичи

**1. Discovery**

- Список популярных/трендовых фильмов с пагинацией
- Поиск с debounce
- Фильтр по жанру
- Переход на экран деталей

**2. Watchlist / Favorites**

- Локальное хранение избранного
- Отражение состояния "в избранном" на экране Discovery

### Навигация

- Tab bar: Discovery / Watchlist
- Push на Detail из обоих табов
- Модальный экран сортировки/фильтров

### Обработка ошибок

TMDB API ограничен для доступа из РФ/РБ (гео-блокировка на уровне CDN).

- Классификация HTTP-ошибок (401 со структурированным телом от TMDB / 403 без тела от CDN) в единую доменную ошибку `AppError`
- Toast-уведомление пользователя о `.regionRestricted`
- Пользователям из затронутых регионов необходим VPN

## Архитектура репозитория

```
TMDB-Showcase.xcworkspace
├── SharedKit/                      (локальный Swift Package)
│   └── Sources/
│       ├── DomainKit/              (Entities, UseCase-протоколы, Repository-протоколы, AppError)
│       └── DataKit/                (DTO, TMDB API client, реализация Repository, маппинг ошибок)
├── MVC-App/
├── MVP-App/
├── MVVM-App/
├── VIPER-App/
├── VIP-App/
└── TCA-App/
```

Domain и Data слои общие для всех 6 модулей. Presentation-слой (Presenter/ViewModel/Interactor/Reducer/Store) уникален для каждой архитектуры и находится в соответствующем `-App` проекте.

## Стек

- Swift, iOS 16+
- SPM
- TMDB REST API
- CI: GitLab CI / Fastlane (планируется)

## Текущий статус

Оформление структуры репозитория и SharedKit-пакета. Реализация начинается с MVC.

## Настройка окружения

1. Получить API-ключ на [themoviedb.org](https://www.themoviedb.org/signup)
2. Скопировать `Config.xcconfig.example` → `Config.xcconfig` в папке нужного `-App` проекта, подставить ключ
3. Пользователям из РФ/РБ — включить VPN для доступа к API
