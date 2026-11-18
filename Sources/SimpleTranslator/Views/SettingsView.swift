import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: Preferences
    @State private var key = ""
    @State private var keyState: SavedKeyState = .unavailable
    @State private var model = ""
    @State private var message: String?
    @State private var models: [ModelOption] = []
    @State private var showModels = false
    @State private var isLoading = false
    @State private var isChecking = false
    @State private var showFreeOptions = false
    @State private var options = ConnectionOptions()
    @State private var awsSecret = ""
    @State private var awsSessionToken = ""
    @AppStorage("fontSize") private var fontSize = 17.0
    private var hasKey: Bool { keyState == .stored }
    private var keyStatus: String {
        if preferences.provider == .myMemory && keyState == .missing { return "Можно использовать без ключа и email" }
        return switch keyState {
        case .stored: "В Связке ключей этого Mac"
        case .missing: "Ключ ещё не добавлен"
        case .unavailable: "Доступ к ключу проверяется при переводе"
        }
    }

    var body: some View {
        Form {
            UpdateSettingsRow()
            Section {
                Picker("Основной сервис", selection: $preferences.provider) {
                    ForEach(Provider.allCases) { provider in Text(provider.title).tag(provider) }
                }
                HStack {
                    SecureField(hasKey ? "Сохранён · введите для замены" : preferences.provider.credentialLabel, text: $key)
                        .textContentType(.password)
                    Button("Сохранить") { saveKey() }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if preferences.provider == .amazon {
                    SecureField("Secret Access Key", text: $awsSecret).textContentType(.password)
                    SecureField("Session Token (только временные ключи)", text: $awsSessionToken).textContentType(.password)
                }
                HStack {
                    Label(keyStatus, systemImage: hasKey ? "lock.fill" : "key")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if keyState != .missing {
                        Button("Удалить ключ", role: .destructive) {
                            do { try Keychain.delete(preferences.provider); keyState = .missing; preferences.revision += 1; message = nil }
                            catch { message = TranslationError.message(for: error) }
                        }.font(.caption)
                    }
                    Link(preferences.provider.requiresKey ? "Получить ключ" : "Условия доступа", destination: preferences.provider.keyURL).font(.caption)
                }
                if let note = preferences.provider.setupNote { Text(note).font(.caption).foregroundStyle(.secondary) }
                if preferences.provider.isNewIntegration {
                    Label(preferences.provider.requiresKey ? "Новое подключение · проверьте своим ключом" : "Новое подключение · проверьте доступность", systemImage: "network")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if preferences.provider == .gigaChat {
                    Link("Официальная инструкция по сертификатам", destination: URL(string: "https://developers.sber.ru/docs/ru/gigachat/certificates")!).font(.caption)
                }
            }
            if [.azure, .amazon, .cloudflare, .gigaChat].contains(preferences.provider) {
                Section("Параметры подключения") {
                    if preferences.provider == .cloudflare { TextField("Account ID", text: $options.accountID) }
                    if preferences.provider == .azure { TextField("Регион Azure (если требуется)", text: $options.region) }
                    if preferences.provider == .amazon {
                        Picker("Регион AWS", selection: $options.region) {
                            Text("Выберите регион").tag("")
                            ForEach(AWSSigner.regions.sorted(), id: \.self) { Text($0).tag($0) }
                        }
                    }
                    if preferences.provider == .gigaChat {
                        Picker("Тип аккаунта", selection: $options.scope) {
                            Text("Личный").tag("GIGACHAT_API_PERS")
                            Text("Бизнес").tag("GIGACHAT_API_B2B")
                            Text("Корпоративный").tag("GIGACHAT_API_CORP")
                        }
                    }
                    Button("Применить параметры") { preferences.connectionOptions = options }
                        .disabled(options == preferences.connectionOptions)
                }
            }
            Section("Основная модель") {
                HStack {
                    TextField("Идентификатор модели", text: $model).onSubmit { saveModel() }
                    Button("Применить") { saveModel() }.disabled(model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model == preferences.model)
                }
                HStack {
                    Button("Выбрать из списка…") { loadModels() }.disabled(isLoading)
                    if isLoading { ProgressView().controlSize(.small) }
                    Spacer()
                    Button(isChecking ? "Проверка…" : "Проверить перевод") { check() }.disabled((preferences.provider.requiresKey && keyState == .missing) || isChecking)
                }
                HStack(alignment: .top) {
                    let selected = models.first(where: { $0.id == preferences.model })
                    Label(selected?.priceDescription ?? preferences.provider.billingLabel(model: preferences.model), systemImage: selected?.isFree == true ? "gift" : "creditcard")
                        .font(.caption).foregroundStyle(selected?.isFree == true ? .green : .secondary)
                    Spacer()
                    Link("Тарифы", destination: preferences.provider.pricingURL).font(.caption)
                }
                Button { showFreeOptions = true } label: {
                    Label("Бесплатные варианты и ограничения…", systemImage: "gift")
                }.font(.callout)
                if preferences.provider == .gemini {
                    Text("Бесплатная квота отмечена по справочнику от 17.11.2026. API не сообщает тариф вашего аккаунта; актуальные условия — по ссылке «Тарифы».")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let message { Text(message).font(.caption).textSelection(.enabled) }
            }
            Section("Варианты слов") {
                Picker("Подбирать через", selection: $preferences.wordProvider) {
                    Text("Автоматически").tag(nil as Provider?)
                    ForEach(Provider.allCases.filter { !$0.isSpecialized }) { Text($0.title).tag(Optional($0)) }
                }
                Text("В автоматическом режиме используется основная модель. Для DeepL и других специализированных переводчиков варианты подбирает Apple Intelligence, если язык доступен на этом Mac. При выборе другого сервиса слово и соседний текст отправляются его настроенной модели по тарифу аккаунта.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Text("Размер текста")
                    Slider(value: $fontSize, in: 13...24, step: 1).frame(width: 200)
                    Text("\(Int(fontSize))").monospacedDigit().foregroundStyle(.secondary)
                }
                Text(preferences.provider.privacyNote).font(.caption).foregroundStyle(.secondary)
                Text("История не сохраняется. Ключ не попадает в файлы приложения, GitHub или iCloud. Перевод начинается после паузы во вводе; каждый новый запрос учитывается сервисом.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Просмотр настроек не запрашивает ключ. macOS может попросить доступ при первом переводе, проверке подключения или загрузке закрытого списка моделей. После разрешения ключ используется из памяти до закрытия приложения.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 620, height: 660)
        .onAppear { reload() }
        .onDisappear { key = ""; awsSecret = ""; awsSessionToken = "" }
        .onChange(of: preferences.provider) { _, _ in reload() }
        .sheet(isPresented: $showFreeOptions) { FreeOptionsView { preferences.provider = $0 } }
        .sheet(isPresented: $showModels) {
            ModelPicker(models: models, current: preferences.model, supportsPrices: [.openRouter, .huggingFace, .sambaNova].contains(preferences.provider)) { selected in
                model = selected.id
                saveModel()
            }
        }
    }
    private func reload() {
        key = ""
        awsSecret = ""
        awsSessionToken = ""
        options = preferences.connectionOptions
        model = preferences.model
        models = []
        message = nil
        keyState = Keychain.savedState(preferences.provider)
        if !preferences.provider.modelListRequiresKey { loadModels(present: false) }
    }
    private func saveKey() {
        do {
            let value: String
            if preferences.provider == .amazon {
                guard !awsSecret.isEmpty else { throw TranslationError.missingParameters }
                value = try AWSCredentials(accessKey: key.trimmingCharacters(in: .whitespacesAndNewlines),
                                           secretKey: awsSecret.trimmingCharacters(in: .whitespacesAndNewlines),
                                           sessionToken: awsSessionToken.trimmingCharacters(in: .whitespacesAndNewlines)).encoded()
            } else { value = key }
            try Keychain.save(value, for: preferences.provider)
            key = ""
            awsSecret = ""
            awsSessionToken = ""
            keyState = .stored
            preferences.revision += 1
            message = "Ключ сохранён."
        } catch { message = TranslationError.message(for: error) }
    }
    private func saveModel() {
        let value = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if preferences.model != value { preferences.model = value }
        model = value
        message = nil
    }
    private func loadModels(present: Bool = true) {
        if present && options != preferences.connectionOptions { preferences.connectionOptions = options }
        let provider = preferences.provider
        let connection = preferences.connectionOptions
        isLoading = true
        message = nil
        Task {
            defer { isLoading = false }
            do {
                let apiKey = provider.modelListRequiresKey ? try Keychain.read(provider) ?? "" : ""
                let found = try await TranslationClient.shared.models(provider: provider, key: apiKey, options: connection)
                guard preferences.provider == provider else { return }
                models = found
                showModels = present
            } catch { if preferences.provider == provider { message = TranslationError.message(for: error) } }
        }
    }
    private func check() {
        if options != preferences.connectionOptions { preferences.connectionOptions = options }
        saveModel()
        let provider = preferences.provider
        isChecking = true
        message = nil
        Task {
            defer { isChecking = false }
            do {
                let config = try preferences.configuration(source: "en", target: "ru")
                let result = try await TranslationClient.shared.translate("Hello, world!", configuration: config) { _ in }
                if provider == preferences.provider { message = "Работает: \(result)" }
            } catch { if provider == preferences.provider { message = TranslationError.message(for: error) } }
        }
    }
}

private struct ModelPicker: View {
    let models: [ModelOption]
    let current: String
    let supportsPrices: Bool
    let select: (ModelOption) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var freeOnly = false
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Модель перевода").font(.headline)
                Spacer()
                Button("Закрыть") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            TextField("Поиск модели", text: $search).textFieldStyle(.roundedBorder)
            if supportsPrices { Toggle("Только бесплатные", isOn: $freeOnly).frame(maxWidth: .infinity, alignment: .leading) }
            List {
                ForEach(models.filter { (!freeOnly || $0.isFree) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search)) }) { option in
                    Button {
                        select(option)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.name).fontWeight(.medium)
                                Text(option.id).font(.caption).foregroundStyle(.secondary)
                                if let price = option.priceDescription { Text(price).font(.caption).foregroundStyle(option.isFree ? .green : .secondary) }
                            }
                            Spacer()
                            if option.id == current { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }.padding(.vertical, 5).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.listStyle(.inset)
            if supportsPrices {
                Text("Цена на момент загрузки списка: вход / выход. Бесплатные модели имеют лимиты и могут стать недоступны.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(20).frame(width: 520, height: 510)
    }
}
