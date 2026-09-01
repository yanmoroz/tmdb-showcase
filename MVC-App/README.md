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
└── MVC-App/
    ├── AppDelegate.swift
    ├── SceneDelegate.swift   сборка окна и корневого контроллера
    ├── AppConfig.swift       чтение TMDB-токена из Info.plist
    ├── Info.plist
    └── Assets.xcassets
```

## Запуск

1. Настроить `Config.xcconfig` в корне репозитория — см. [README репозитория](../README.md#настройка-окружения)
2. Открыть `TMDB-Showcase.xcworkspace`
3. Схема `MVC-App`, симулятор iOS 17+

## Статус

Экранов нет: `SceneDelegate` ставит корнем заглушку с заголовком «Movies». Следующий шаг — список фильмов с пагинацией, поиском и фильтром по жанру. Тест-таргет появится вместе с первым контроллером.
