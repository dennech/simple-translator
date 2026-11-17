import Foundation

enum Provider: String, CaseIterable, Identifiable, Codable {
    case openRouter, gemini, openAI, deepL
    var id: String { rawValue }
    var title: String {
        switch self { case .openRouter: "OpenRouter API"; case .gemini: "Gemini API"; case .openAI: "OpenAI API"; case .deepL: "DeepL API" }
    }
    var defaultModel: String {
        switch self {
        case .openRouter: "google/gemini-3.8-flash"
        case .gemini: "gemini-3.8-flash"
        case .openAI: "gpt-4.1-mini"
        case .deepL: "prefer_quality_optimized"
        }
    }
    var baseURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/api/v1/")!
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/")!
        case .openAI: URL(string: "https://api.openai.com/v1/")!
        case .deepL: URL(string: "https://api.deepl.com/v2/")!
        }
    }
    var keyURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/settings/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/apikey")!
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .deepL: URL(string: "https://www.deepl.com/your-account/keys")!
        }
    }
    var privacyNote: String {
        switch self {
        case .openRouter: "Текст отправляется OpenRouter и выбранному поставщику модели. Запрещена маршрутизация к поставщикам, использующим данные для обучения. Стоимость — по тарифу модели."
        case .gemini: "Текст отправляется Google. На бесплатном уровне Google может использовать запросы для улучшения своих продуктов. Лимиты и доступность зависят от аккаунта и региона."
        case .openAI: "Текст отправляется напрямую в OpenAI API. Это платное API: расходы учитываются отдельно от подписки ChatGPT. Сохранение ответов через API выключено."
        case .deepL: "Текст отправляется DeepL. Нужен отдельный ключ DeepL API; подписка на приложение DeepL его не заменяет. Набор языков зависит от DeepL."
        }
    }

    var pricingURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/models")!
        case .gemini: URL(string: "https://ai.google.dev/gemini-api/docs/pricing")!
        case .openAI: URL(string: "https://openai.com/api/pricing/")!
        case .deepL: URL(string: "https://www.deepl.com/pro-api")!
        }
    }

    func billingLabel(model: String) -> String {
        switch self {
        case .openRouter: return "Стоимость: обновите список моделей"
        case .openAI: return "Платно · по использованию API"
        case .deepL: return "Developer: разовая квота · старый Free: месячная · Pro: платно"
        case .gemini:
            if Self.geminiFreeTierModels.contains(model) { return "Есть бесплатная квота · на платном аккаунте — по тарифу" }
            return "Тариф не указан API · проверьте у Google"
        }
    }
    // Official pricing checked 2026-11-17. Not an assertion about the user's billing tier.
    static let geminiFreeTierModels: Set<String> = ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-3.8-flash", "gemini-3.5-flash-lite"]
}

struct TranslationConfiguration: Equatable, Sendable {
    let provider: Provider
    let model: String
    let key: String
    let source: String
    let target: String
}

struct ModelOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var inputPrice: Double? = nil
    var outputPrice: Double? = nil
    var requestPrice: Double = 0
    var billing: String? = nil
    var isFree: Bool { inputPrice == 0 && outputPrice == 0 && requestPrice == 0 }
    var priceDescription: String? {
        guard let inputPrice, let outputPrice else { return billing }
        guard inputPrice >= 0, outputPrice >= 0, requestPrice >= 0 else { return "Переменная цена · зависит от модели" }
        if isFree { return "Бесплатно" }
        let tokens = String(format: "$%.4g / $%.4g за 1 млн токенов", inputPrice * 1_000_000, outputPrice * 1_000_000)
        return requestPrice > 0 ? tokens + String(format: " + $%.4g за запрос", requestPrice) : tokens
    }
}
