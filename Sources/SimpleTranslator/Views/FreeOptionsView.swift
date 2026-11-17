import SwiftUI

private struct FreeOption: Decodable, Identifiable {
    let id: String
    let title: String
    let availability: String
    let summary: String
    let limit: String
    let caution: String
    let url: URL
}

struct FreeOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private let options: [FreeOption] = {
        guard let url = Bundle.main.url(forResource: "FreeOptions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let options = try? JSONDecoder().decode([FreeOption].self, from: data) else { return [] }
        return options
    }()
    private let groups = [
        ("supported", "Можно подключить сейчас"),
        ("other", "Другие API · пока не подключены"),
        ("local", "Локально · пока не подключено"),
        ("trial", "Пробные и ограниченные предложения")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Бесплатные варианты", systemImage: "gift.fill")
                    .font(.title2.weight(.semibold)).foregroundStyle(.indigo)
                Spacer()
                Button("Готово") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Справочник · 17 ноября 2026. Квоты, страны и условия могут меняться. «Бесплатно» не означает безлимитно.")
                .font(.callout).foregroundStyle(.secondary)
            TextField("Найти сервис или локальный вариант", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groups, id: \.0) { group in
                        let items = options.filter {
                            $0.availability == group.0 && (query.isEmpty ||
                                ($0.title + " " + $0.summary).localizedCaseInsensitiveContains(query))
                        }
                        if !items.isEmpty {
                            Text(group.1).font(.headline).padding(.top, 4)
                            ForEach(items) { option in
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(option.title).font(.headline)
                                        Spacer()
                                        Link("Условия ↗", destination: option.url).font(.caption)
                                    }
                                    Text(option.summary).font(.callout)
                                    Text(option.limit).font(.callout.weight(.medium)).foregroundStyle(.indigo)
                                    Text(option.caution).font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    if options.isEmpty { Text("Справочник не загружен. Откройте полную версию по ссылке ниже.").foregroundStyle(.secondary) }
                }.padding(.trailing, 8)
            }
            Link("Полное сравнение и источники ↗", destination: URL(string: "https://github.com/dennech/simple-translator/blob/main/docs/free-translation-options.md")!)
                .font(.callout)
        }
        .padding(22)
        .frame(width: 650, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
