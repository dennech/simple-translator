import SwiftUI
import AppKit

struct TranslationTrigger: Equatable {
    let text: String
    let source: String
    let target: String
    let revision: Int
}

struct ContentView: View {
    @Bindable var store: TranslatorStore
    @Bindable var preferences: Preferences
    @AppStorage("fontSize") private var fontSize = 17.0
    @State private var copied = false
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack {
                    LanguageButton(selection: $store.sourceLanguage, detected: store.detectedLanguage, isSource: true)
                    Spacer(minLength: 4)
                    iconButton("xmark", help: "Очистить текст", action: store.clear)
                        .disabled(store.sourceText.isEmpty)
                }.frame(maxWidth: .infinity)
                Button(action: store.swap) {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue).frame(width: 34, height: 30)
                        .background(.blue.opacity(colorScheme == .dark ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).help("Поменять языки (⌘⇧S)").accessibilityLabel("Поменять языки")
                    .padding(.horizontal, 18)
                HStack {
                    LanguageButton(selection: $store.targetLanguage, detected: store.sourceText.isEmpty ? nil : store.resolvedTarget)
                    Spacer(minLength: 4)
                    if store.isTranslating { ProgressView().controlSize(.small).scaleEffect(0.8).frame(width: 20) }
                    iconButton(copied ? "checkmark" : "doc.on.doc", help: "Скопировать перевод (⌘⇧C)", action: copy)
                        .disabled(!store.isComplete)
                }.frame(maxWidth: .infinity)
            }.padding(.horizontal, 30).frame(height: 52)
            HSplitView {
                pane(text: $store.sourceText, placeholder: "Текст", editable: true)
                pane(text: .constant(store.translatedText), placeholder: "Перевод", editable: false)
            }.padding(.horizontal, 12).padding(.bottom, 12)
            if let error = store.error {
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary)
                    Text(error).font(.system(size: 12)).textSelection(.enabled)
                    Spacer(minLength: 8)
                    Button("Повторить") { store.schedule(preferences: preferences, immediately: true) }.controlSize(.small)
                    SettingsLink { Image(systemName: "gearshape") }.buttonStyle(.borderless).help("Настройки")
                }.padding(12)
            }
        }
        .background {
            LinearGradient(colors: [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(colorScheme == .dark ? 0.06 : 0.035)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .frame(minWidth: 620, minHeight: 300)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                SettingsLink { Image(systemName: "gearshape").font(.system(size: 12)) }.help("Настройки (⌘,)")
            }
        }
        .onChange(of: TranslationTrigger(text: store.sourceText, source: store.sourceLanguage, target: store.targetLanguage, revision: preferences.revision)) { _, _ in
            copied = false
            store.schedule(preferences: preferences)
        }
        .background {
            Group {
                Button("") { store.swap() }.keyboardShortcut("s", modifiers: [.command, .shift])
                Button("") { copy() }.keyboardShortcut("c", modifiers: [.command, .shift]).disabled(!store.isComplete)
                Button("") { store.schedule(preferences: preferences, immediately: true) }.keyboardShortcut(.return, modifiers: .command)
                Button("") { store.clear() }.keyboardShortcut(.delete, modifiers: .command)
            }.hidden()
        }
    }

    private func pane(text: Binding<String>, placeholder: String, editable: Bool) -> some View {
        PlainTextPane(text: text, editable: editable, fontSize: fontSize)
            .overlay(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder).font(.system(size: fontSize)).foregroundStyle(.tertiary)
                        .padding(.horizontal, 22).padding(.top, 20).allowsHitTesting(false)
                }
            }
            .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Color(nsColor: .textBackgroundColor)
                    if !editable { Color.blue.opacity(colorScheme == .dark ? 0.065 : 0.025) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(editable ? Color.primary.opacity(0.055) : Color.blue.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 4)
    }
    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 13)).frame(width: 24, height: 24).contentShape(Rectangle()) }
            .buttonStyle(.borderless).foregroundStyle(.secondary).help(help).accessibilityLabel(help)
    }
    private func copy() {
        guard store.isComplete else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(store.translatedText, forType: .string)
        copied = true
    }
}
