# MVC-App

Реализация демо-приложения на UIKit + MVC. Домен и данные — из [SharedKit](../SharedKit/README.md), здесь только Presentation.

- iOS 17+, Swift 6 language mode
- UIKit, `AppDelegate` + `SceneDelegate`
- Bundle ID `yanmoroz.tmdb.mvc`, iPhone + iPad

## Особенности

**Без storyboard и xib.** Вся вёрстка кодом.

- `Main.storyboard` и ключ `UISceneStoryboardFile` в scene-манифесте удалены; окно и корневой контроллер собирает `SceneDelegate`
- Вместо `LaunchScreen.storyboard` — пустой `UILaunchScreen` в `Info.plist`
- Правило распространяется на все шесть `-App` проектов

**`Info.plist` — реальный файл** (`INFOPLIST_FILE`) при включённом `GENERATE_INFOPLIST_FILE`. В файле только то, что не выражается build settings: `TMDBAccessToken`, scene-манифест, `UILaunchScreen`. Ориентации и прочие `INFOPLIST_KEY_*` — в build settings, дублировать их в файле не нужно.

**Токен: `Config.xcconfig` → `Info.plist` → `AppConfig`.** `Config.xcconfig` лежит в корне репозитория и подключён к проекту как base configuration (`../Config.xcconfig`). Читает токен [AppConfig.swift](MVC-App/AppConfig.swift) — единственное место, где используется `Bundle.main`. Незаполненный токен даёт `fatalError` на старте.

**Открывать `TMDB-Showcase.xcworkspace`.** `SharedKit` подключён как локальный пакет workspace; отдельно открытый `MVC-App.xcodeproj` не найдёт `DomainKit` и `DataKit`.

**`MainActor` по умолчанию** — `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` плюс `SWIFT_APPROACHABLE_CONCURRENCY`. Presentation-код изолирован на главном акторе без аннотаций, уход с него пишется явным `nonisolated`. На `SharedKit` не распространяется: пакет собирается со своими флагами.

## Структура

```
MVC-App/
├── MVC-App.xcodeproj
├── MVC-App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift          окно и композиционный корень
│   ├── AppConfig.swift              чтение TMDB-токена из Info.plist
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

`Common/` — заготовка под общий UI-пакет: компоненты принимают плоские значения и ничего не знают про контроллер. Извлечение планируется на этапе MVP, когда станет видно, что реально повторяется.

## Запуск

1. Настроить `Config.xcconfig` в корне репозитория — см. [README репозитория](../README.md#настройка-окружения)
2. Открыть `TMDB-Showcase.xcworkspace`
3. Схема `MVC-App`, симулятор iOS 17+

## Что показывает MVC здесь

Трактовка выбрана намеренно буквальной: `MoviesViewController` держит накопленный список, курсор страницы и текущую `Task`, сам реализует `UICollectionViewDataSource` и `UICollectionViewDelegate`, сам зовёт `FetchMovies` и сам разбирает `AppError`. Это тот самый Massive View Controller — базовая линия, относительно которой будут сравниваться пять остальных реализаций.

По той же причине взят классический `dataSource`, а не diffable: он оставляет на виду возню с состоянием, ради показа которой всё и затевается.

Пустые состояния — загрузка, пустой результат, ошибка с кнопкой повтора — сделаны на `contentUnavailableConfiguration` (iOS 17+), а не собственной вьюхой. Своя реализация была написана и удалена: UIKit закрывает все три случая первой стороной, а `searchConfiguration` пригодится для пустой выдачи поиска. В TCA-версии на SwiftUI роль возьмёт `ContentUnavailableView` — так что в общий UI-пакет это не поедет вовсе.

Тесты в `MVC-AppTests` меряют цену этого решения. Чтобы проверить пагинацию, приходится поднять вьюху целиком, найти `UICollectionView` обходом иерархии и ждать внутреннюю `Task` опросом — наружу она не выставлена. В MVP те же проверки станут вызовом метода презентера.

## Статус

Экран списка популярных фильмов готов: сетка постеров, пагинация, состояния загрузки / пусто / ошибка, тост про VPN на `.regionRestricted`, pull-to-refresh. Следующий шаг — поиск с debounce и фильтр по жанру, затем экран деталей.
