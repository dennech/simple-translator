import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: Preferences
    @State private var key = ""
    @State private var hasKey = false
    @State private var model = ""
    @State private var message: String?
    @State private var models: [ModelOption] = []
    @State private var showModels = false
    @State private var isLoading = false
    @State private var isChecking = false
    @State private var showFreeOptions = false
    @AppStorage("fontSize") private var fontSize = 17.0

    var body: some View {
        Form {
            Section {
                Picker("Основной сервис", selection: $preferences.provider) {
                    ForEach(Provider.allCases) { provider in Text(provider.title).tag(provider) }
                }
                HStack {
                    SecureField(hasKey ? "Ключ сохранён · введите новый для замены" : "API-ключ", text: $key)
                        .textContentType(.password)
                    Button("Сохранить") { saveKey() }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                HStack {
                    Label(hasKey ? "В Связке ключей этого Mac" : "Ключ ещё не добавлен", systemImage: hasKey ? "lock.fill" : "key")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if hasKey {
                        Button("Удалить ключ", role: .destructive) {
                            do { try Keychain.delete(preferences.provider); hasKey = false; preferences.revision += 1; message = nil }
                            catch { message = TranslationError.message(for: error) }
                        }.font(.caption)
                    }
                    Link("Получить ключ", destination: preferences.provider.keyURL).font(.caption)
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
                    Button(isChecking ? "Проверка…" : "Проверить перевод") { check() }.disabled(!hasKey || isChecking)
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
            Section {
                HStack {
                    Text("Размер текста")
                    Slider(value: $fontSize, in: 13...24, step: 1).frame(width: 200)
                    Text("\(Int(fontSize))").monospacedDigit().foregroundStyle(.secondary)
                }
                Text(preferences.provider.privacyNote).font(.caption).foregroundStyle(.secondary)
                Text("История не сохраняется. Ключ не попадает в файлы приложения, GitHub или iCloud. Перевод начинается после паузы во вводе; каждый новый запрос учитывается сервисом.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("macOS может запросить доступ к ключу при первом запуске или обновлении. После разрешения ключ используется из памяти до закрытия приложения.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 590, height: 595)
        .onAppear { reload() }
        .onDisappear { key = "" }
        .onChange(of: preferences.provider) { _, _ in reload() }
        .sheet(isPresented: $showFreeOptions) { FreeOptionsView() }
        .sheet(isPresented: $showModels) {
            ModelPicker(models: models, current: preferences.model, supportsPrices: preferences.provider == .openRouter) { selected in
                model = selected.id
                saveModel()
            }
        }
    }
    private func reload() {
        key = ""
        model = preferences.model
        models = []
        message = nil
        do { hasKey = try Keychain.read(preferences.provider) != nil }
        catch { hasKey = false; message = TranslationError.message(for: error) }
        if hasKey || preferences.provider == .openRouter || preferences.provider == .deepL { loadModels(present: false) }
    }
    private func saveKey() {
        do {
            try Keychain.save(key, for: preferences.provider)
            key = ""
            hasKey = true
            preferences.revision += 1
            message = "Ключ сохранён."
        } catch { message = TranslationError.message(for: error) }
    }
    private func saveModel() {
        let value = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        preferences.model = value
        model = value
        message = nil
    }
    private func loadModels(present: Bool = true) {
        let provider = preferences.provider
        isLoading = true
        message = nil
        Task {
            defer { isLoading = false }
            do {
                let found = try await TranslationClient.shared.models(provider: provider, key: Keychain.read(provider) ?? "")
                guard preferences.provider == provider else { return }
                models = found
                showModels = present
            } catch { if preferences.provider == provider { message = TranslationError.message(for: error) } }
        }
    }
    private func check() {
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
