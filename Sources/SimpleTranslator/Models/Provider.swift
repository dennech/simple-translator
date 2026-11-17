import Foundation

enum Provider: String, CaseIterable, Identifiable, Codable, Sendable {
    case openRouter, gemini, openAI, deepL, azure, googleCloud, myMemory, groq, cloudflare, cerebras, fireworks, nvidia, amazon, mistral, huggingFace, together, sambaNova, yandex, gigaChat, siliconFlow
    var id: String { rawValue }
    private var info: ProviderInfo { Self.catalog[self]! }
    var title: String { info.title }
    var baseURL: URL { URL(string: info.baseURL)! }
    var keyURL: URL { URL(string: info.keyURL)! }
    var pricingURL: URL { URL(string: info.pricingURL)! }
    var requiresKey: Bool { self != .myMemory }
    var isSpecialized: Bool { [.deepL, .azure, .googleCloud, .myMemory, .amazon, .yandex].contains(self) }
    var modelListRequiresKey: Bool { !isSpecialized && self != .openRouter && self != .huggingFace }
    var isNewIntegration: Bool { ![.openRouter, .openAI, .gemini, .deepL].contains(self) }
    var defaultModel: String {
        switch self {
        case .openRouter: "google/gemini-3.8-flash"
        case .gemini: "gemini-3.8-flash"
        case .openAI: "gpt-4.1-mini"
        case .deepL: "prefer_quality_optimized"
        default: isSpecialized ? "standard" : ""
        }
    }
    var credentialLabel: String {
        switch self {
        case .amazon: "Access Key ID"
        case .gigaChat: "Ключ авторизации (Authorization Key)"
        case .myMemory: "Email для увеличения квоты (необязательно)"
        case .huggingFace: "Токен Hugging Face"
        case .cloudflare: "API-токен Workers AI"
        default: "API-ключ"
        }
    }
    var setupNote: String? {
        switch self {
        case .amazon: "Access Key ID, Secret Access Key и Session Token сохраняются вместе в Связке ключей. Нужны права translate:TranslateText."
        case .azure: "Для регионального или общего ресурса укажите его регион; у глобального ресурса поле можно оставить пустым."
        case .googleCloud: "Нужен ключ проекта с включённым Cloud Translation Basic API и оплатой."
        case .myMemory: "Работает без ключа. Email необязателен и отправляется MyMemory для увеличения квоты. Не используйте для закрытой переписки."
        case .cloudflare: "Укажите Account ID из панели Cloudflare и токен с разрешением Workers AI: Read."
        case .yandex: "Нужен API-ключ сервисного аккаунта с правами перевода. IAM-токен в этом режиме не используется; folderId передавать не нужно."
        case .gigaChat: "Вставьте готовый ключ авторизации из кабинета, а не временный access token. OAuth требует доверия macOS к сертификатам сервиса."
        case .huggingFace: "Выберите модель с суффиксом :поставщик. Автоматический выбор и смена поставщика не используются."
        default: nil
        }
    }
    var privacyNote: String {
        switch self {
        case .openRouter: "Текст отправляется OpenRouter и выбранному поставщику модели. Запрещена маршрутизация к поставщикам, использующим данные для обучения."
        case .gemini: "Текст отправляется Google. Бесплатный уровень может использовать запросы для улучшения продуктов. Доступ зависит от аккаунта и региона."
        case .openAI: "Текст отправляется напрямую в OpenAI API. Расходы учитываются отдельно от ChatGPT. Сохранение ответов через API выключено."
        case .deepL: "Текст отправляется DeepL. Нужен отдельный ключ API; подписка на приложение DeepL его не заменяет."
        case .myMemory: "Текст передаётся MyMemory в адресе запроса по контракту API. Сервис может долго хранить сегменты и привлекать внешних поставщиков."
        case .huggingFace: "Текст проходит через Hugging Face и выбранного поставщика. Проверьте правила хранения и тариф этого маршрута."
        default: "Текст отправляется выбранному официальному API. Лимиты, стоимость и обработка данных определяются условиями сервиса."
        }
    }
    func billingLabel(model: String) -> String {
        switch self {
        case .openRouter: "Стоимость: обновите список моделей"
        case .openAI: "Платно · по использованию API"
        case .deepL: "Developer: разовая квота · старый Free: месячная · Pro: платно"
        case .gemini: Self.geminiFreeTierModels.contains(model) ? "Есть бесплатная квота · на платном аккаунте — по тарифу" : "Тариф не указан API · проверьте у Google"
        case .azure: "F0: 2 млн знаков/месяц · остальные планы платные"
        case .googleCloud: "NMT: 500 тыс. знаков/месяц · превышение платное"
        case .myMemory: "Бесплатная квота · 5 тыс. знаков/сутки без email"
        case .groq: "Есть бесплатный уровень · лимиты зависят от модели"
        case .cloudflare: "10 тыс. Neurons/сутки · не все модели бесплатны"
        case .cerebras: "Пробный кредит по условиям аккаунта · далее платно"
        case .fireworks, .siliconFlow: "Возможен разовый бонус · далее платно"
        case .nvidia: "Пробный доступ · ограничения использования"
        case .amazon: "Временная льгота AWS · затем по тарифу"
        case .gigaChat: "Freemium для личного использования · проверьте доступ"
        case .mistral, .sambaNova: "Бесплатный API не подтверждён · проверьте тариф"
        case .huggingFace, .together, .yandex: "Платный API · условия в кабинете"
        }
    }
    // Dated hints, not a statement about the user's actual billing account.
    static let geminiFreeTierModels: Set<String> = ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-3.8-flash", "gemini-3.5-flash-lite"]
    private static let catalog: [Provider: ProviderInfo] = [
        .openRouter: ProviderInfo(title: "OpenRouter API", baseURL: "https://openrouter.ai/api/v1/", keyURL: "https://openrouter.ai/settings/keys", pricingURL: "https://openrouter.ai/models"),
        .gemini: ProviderInfo(title: "Gemini API", baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/", keyURL: "https://aistudio.google.com/apikey", pricingURL: "https://ai.google.dev/gemini-api/docs/pricing"),
        .openAI: ProviderInfo(title: "OpenAI API", baseURL: "https://api.openai.com/v1/", keyURL: "https://platform.openai.com/api-keys", pricingURL: "https://openai.com/api/pricing/"),
        .deepL: ProviderInfo(title: "DeepL API", baseURL: "https://api.deepl.com/v2/", keyURL: "https://www.deepl.com/your-account/keys", pricingURL: "https://www.deepl.com/pro-api"),
        .azure: ProviderInfo(title: "Azure Translator", baseURL: "https://api.cognitive.microsofttranslator.com/", keyURL: "https://learn.microsoft.com/en-us/azure/ai-services/translator/text-translation/reference/authentication", pricingURL: "https://azure.microsoft.com/en-us/pricing/details/translator/"),
        .googleCloud: ProviderInfo(title: "Google Cloud Translation", baseURL: "https://translation.googleapis.com/", keyURL: "https://docs.cloud.google.com/translate/docs/setup", pricingURL: "https://cloud.google.com/products/translate/pricing"),
        .myMemory: ProviderInfo(title: "MyMemory", baseURL: "https://api.mymemory.translated.net/", keyURL: "https://mymemory.translated.net/doc/spec.php", pricingURL: "https://mymemory.translated.net/doc/usagelimits.php"),
        .groq: ProviderInfo(title: "Groq", baseURL: "https://api.groq.com/openai/v1/", keyURL: "https://console.groq.com/keys", pricingURL: "https://console.groq.com/docs/rate-limits"),
        .cloudflare: ProviderInfo(title: "Cloudflare Workers AI", baseURL: "https://api.cloudflare.com/client/v4/", keyURL: "https://developers.cloudflare.com/workers-ai/get-started/rest-api/", pricingURL: "https://developers.cloudflare.com/workers-ai/platform/pricing/"),
        .cerebras: ProviderInfo(title: "Cerebras", baseURL: "https://api.cerebras.ai/v1/", keyURL: "https://inference-docs.cerebras.ai/quickstart", pricingURL: "https://www.cerebras.ai/pricing"),
        .fireworks: ProviderInfo(title: "Fireworks AI", baseURL: "https://api.fireworks.ai/inference/v1/", keyURL: "https://docs.fireworks.ai/getting-started/quickstart", pricingURL: "https://fireworks.ai/pricing"),
        .nvidia: ProviderInfo(title: "NVIDIA NIM", baseURL: "https://integrate.api.nvidia.com/v1/", keyURL: "https://build.nvidia.com/", pricingURL: "https://build.nvidia.com/"),
        .amazon: ProviderInfo(title: "Amazon Translate", baseURL: "https://translate.us-east-1.amazonaws.com/", keyURL: "https://docs.aws.amazon.com/translate/latest/dg/getting-started.html", pricingURL: "https://aws.amazon.com/translate/pricing/"),
        .mistral: ProviderInfo(title: "Mistral", baseURL: "https://api.mistral.ai/v1/", keyURL: "https://console.mistral.ai/", pricingURL: "https://docs.mistral.ai/admin/billing-usage/usage-limits"),
        .huggingFace: ProviderInfo(title: "Hugging Face", baseURL: "https://router.huggingface.co/v1/", keyURL: "https://huggingface.co/settings/tokens", pricingURL: "https://huggingface.co/docs/inference-providers/pricing"),
        .together: ProviderInfo(title: "Together AI", baseURL: "https://api.together.ai/v1/", keyURL: "https://api.together.ai/settings/projects/~current/api-keys", pricingURL: "https://docs.together.ai/docs/billing-credits"),
        .sambaNova: ProviderInfo(title: "SambaNova", baseURL: "https://api.sambanova.ai/v1/", keyURL: "https://docs.sambanova.ai/docs/en/get-started/api-keys-urls", pricingURL: "https://cloud.sambanova.ai/plans"),
        .yandex: ProviderInfo(title: "Yandex Translate", baseURL: "https://translate.api.cloud.yandex.net/", keyURL: "https://aistudio.yandex.ru/ru/docs/ai-studio/operations/get-api-key", pricingURL: "https://aistudio.yandex.ru/ru/docs/ai-studio/pricing"),
        .gigaChat: ProviderInfo(title: "GigaChat", baseURL: "https://api.giga.chat/v1/", keyURL: "https://developers.sber.ru/docs/ru/gigachat/quickstart/ind-using-api", pricingURL: "https://developers.sber.ru/docs/ru/gigachat/tariffs/individual-tariffs"),
        .siliconFlow: ProviderInfo(title: "SiliconFlow", baseURL: "https://api.siliconflow.com/v1/", keyURL: "https://cloud.siliconflow.com/account/ak", pricingURL: "https://www.siliconflow.com/pricing")
    ]
}
private struct ProviderInfo {
    let title: String
    let baseURL: String
    let keyURL: String
    let pricingURL: String
}
struct ConnectionOptions: Codable, Equatable, Sendable {
    var accountID = ""
    var region = ""
    var scope = "GIGACHAT_API_PERS"
}
struct TranslationConfiguration: Equatable, Sendable {
    let provider: Provider
    let model: String
    let key: String
    let source: String
    let target: String
    var options = ConnectionOptions()
}
struct AWSCredentials: Codable, Equatable, Sendable {
    let accessKey: String
    let secretKey: String
    let sessionToken: String
    static func decode(_ value: String) throws -> Self {
        guard let data = value.data(using: .utf8), let result = try? JSONDecoder().decode(Self.self, from: data),
              !result.accessKey.isEmpty, !result.secretKey.isEmpty else { throw TranslationError.missingParameters }
        return result
    }
    func encoded() throws -> String { String(decoding: try JSONEncoder().encode(self), as: UTF8.self) }
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
