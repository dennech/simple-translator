import Foundation

enum TranslationError: LocalizedError, Equatable {
    case missingKey, invalidResponse, emptyResponse, interrupted, truncated, filtered, server(Int)
    var errorDescription: String? {
        switch self {
        case .missingKey: "Добавьте API-ключ в настройках (⌘,)."
        case .invalidResponse: "Сервис вернул непонятный ответ. Попробуйте другую модель."
        case .emptyResponse: "Модель не вернула перевод. Попробуйте другую модель."
        case .interrupted: "Соединение прервалось. Перевод не завершён — повторите попытку."
        case .truncated: "Модель остановилась до конца текста. Перевод не завершён — выберите другую модель."
        case .filtered: "Сервис отказался переводить этот текст. Выберите другую модель или сервис."
        case .server(let status):
            switch status {
            case 401, 403: "Сервис отклонил запрос: проверьте ключ, доступ к модели и регион."
            case 402: "На счёте сервиса недостаточно средств."
            case 404: "Модель больше недоступна. Обновите список в настройках."
            case 413: "Текст слишком большой для этой модели. Выберите другую модель."
            case 429: "Достигнут лимит запросов. Подождите немного или выберите другую модель."
            case 456: "Исчерпан лимит DeepL API."
            case 500...599: "Сервис временно недоступен (\(status)). Повторите попытку."
            default: "Сервис отклонил запрос (\(status)). Проверьте модель и языки в настройках."
            }
        }
    }
    static func message(for error: Error) -> String {
        if let known = error as? TranslationError { return known.localizedDescription }
        if let known = error as? KeychainError { return known.localizedDescription }
        if let network = error as? URLError {
            return network.code == .timedOut ? "Сервис не ответил вовремя. Повторите попытку." : "Нет связи с сервисом. Проверьте интернет и VPN."
        }
        // Never expose a remote response body, request URL, API key or original text in errors.
        return "Не удалось выполнить запрос. Проверьте подключение и настройки."
    }
}
