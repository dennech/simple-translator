import SwiftUI

struct LanguageButton: View {
    @Binding var selection: String
    var detected: String?
    var isSource = false
    @State private var showAll = false
    var label: String {
        if selection == Languages.auto, let detected { return "Авто · \(Languages.name(detected).lowercased())" }
        return Languages.name(selection)
    }

    var body: some View {
        Menu {
            Button(isSource ? "Определять автоматически" : "Авто: русский ↔ английский") { selection = Languages.auto }
            Divider()
            ForEach(Languages.common, id: \.self) { code in
                Button { selection = code } label: {
                    if selection == code { Label(Languages.name(code), systemImage: "checkmark") }
                    else { Text(Languages.name(code)) }
                }
            }
            Divider()
            Button("Все языки…") { showAll = true }
        } label: {
            Text(label).font(.system(size: 13, weight: .medium)).lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(isSource ? "Язык оригинала" : "Язык перевода")
        .sheet(isPresented: $showAll) { LanguageSheet(selection: $selection) }
    }
}

private struct LanguageSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Язык").font(.headline)
                Spacer()
                Button("Готово") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            TextField("Найти язык", text: $search).textFieldStyle(.roundedBorder)
            List {
                ForEach(Languages.all.filter { search.isEmpty || Languages.name($0).localizedCaseInsensitiveContains(search) || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { code in
                    Button { selection = code; dismiss() } label: {
                        HStack { Text(Languages.name(code)); Spacer(); if selection == code { Image(systemName: "checkmark") } }
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(.vertical, 3)
                }
            }.listStyle(.inset)
        }.padding(20).frame(width: 340, height: 460)
    }
}
