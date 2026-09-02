import DomainKit

extension AppError {
    var message: String {
        switch self {
        case .regionRestricted:
            "TMDB недоступен из вашего региона. Включите VPN и повторите."
        case .unauthorized:
            "Ключ доступа к TMDB не принят. Проверьте Config.xcconfig."
        case .notFound:
            "Фильм не найден."
        case .rateLimited:
            "Слишком много запросов. Попробуйте через минуту."
        case .server:
            "Сервис TMDB временно недоступен."
        case .network(.offline):
            "Нет соединения с интернетом."
        case .network(.timedOut):
            "Сервер не ответил вовремя."
        case .network(.cannotConnect), .network(.other):
            "Не удалось связаться с сервером."
        case .decoding:
            "Сервер вернул неожиданный ответ."
        case .cancelled:
            "Запрос отменён."
        case .unknown:
            "Что-то пошло не так."
        }
    }
}
