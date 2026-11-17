import AppKit
import SwiftUI

/// The store owns the text. This snapshot identifies which finished translation a click belongs to.
@MainActor struct WordActions {
    let id: UUID
    let language: String
    let load: (TranslationWord) async throws -> [WordAlternative]
    let replace: (WordAlternative) -> Void
    let selectProvider: (Provider) -> Void
}

@MainActor final class TranslationTextView: NSTextView {
    var actions: WordActions? {
        didSet { if actions?.id != oldValue?.id { dismissAlternatives() } }
    }
    private var popover: NSPopover?

    override func mouseDown(with event: NSEvent) {
        dismissAlternatives()
        let point = convert(event.locationInWindow, from: nil)
        super.mouseDown(with: event)
        guard event.clickCount == 1, event.modifierFlags.intersection([.control, .option, .shift]).isEmpty,
              selectedRange().length == 0, let actions,
              let hit = word(at: point, language: actions.language) else { return }
        showAlternatives(hit.word, rect: hit.rect, actions: actions)
    }

    func word(at point: NSPoint, language: String) -> (word: TranslationWord, rect: NSRect)? {
        guard let container = textContainer, let layout = layoutManager else { return nil }
        let origin = textContainerOrigin
        let location = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
        let glyph = layout.glyphIndex(for: location, in: container)
        guard glyph < layout.numberOfGlyphs,
              layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container).contains(location),
              let word = TranslationWord(text: string, characterOffset: layout.characterIndexForGlyph(at: glyph),
                                         language: language) else { return nil }
        var line = NSRange()
        _ = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &line)
        let part = NSIntersectionRange(line, layout.glyphRange(forCharacterRange: word.range, actualCharacterRange: nil))
        let rect = layout.boundingRect(forGlyphRange: part, in: container).offsetBy(dx: origin.x, dy: origin.y)
        return (word, rect)
    }

    private func showAlternatives(_ word: TranslationWord, rect: NSRect, actions: WordActions) {
        let panel = NSPopover()
        panel.behavior = .transient
        panel.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let list = AlternativesList(word: word, load: actions.load, selectProvider: actions.selectProvider, preview: { [weak self] range in
            guard let self, self.actions?.id == actions.id else { return }
            self.setSelectedRange(range ?? word.range)
        }) { [weak self] alternative in
            guard let self, self.actions?.id == actions.id else { return }
            self.dismissAlternatives()
            actions.replace(alternative)
        }
        let content = NSHostingController(rootView: list)
        content.sizingOptions = [.preferredContentSize]
        panel.contentViewController = content
        popover = panel
        setSelectedRange(word.range)
        panel.show(relativeTo: rect, of: self, preferredEdge: .maxY)
    }

    func dismissAlternatives() {
        popover?.close()
        popover = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { dismissAlternatives() }
    }
}

private struct AlternativesList: View {
    let word: TranslationWord
    let load: @MainActor (TranslationWord) async throws -> [WordAlternative]
    let selectProvider: @MainActor (Provider) -> Void
    let preview: @MainActor (NSRange?) -> Void
    let choose: @MainActor (WordAlternative) -> Void
    @State private var choices: [WordAlternative] = []
    @State private var message: String?
    @State private var loading = true
    @State private var needsProvider = false
    @State private var attempt = 0
    @State private var hovered: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if loading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Подбираем варианты…")
                }.font(.callout).foregroundStyle(.secondary).padding(8)
            } else if let message {
                Text(message).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(6)
                if !needsProvider {
                    Button("Повторить") { attempt += 1 }.buttonStyle(.link).font(.caption).padding(6)
                }
                Menu("Выбрать сервис подсказок…") {
                    ForEach(Provider.allCases.filter { !$0.isSpecialized }) { provider in
                        Button(provider.title) { selectProvider(provider); attempt += 1 }
                    }
                }.controlSize(.small).padding(4)
            } else if choices.isEmpty {
                Text("Подходящих замен нет").font(.callout).foregroundStyle(.secondary).padding(8)
            } else {
                ForEach(choices, id: \.replacement) { item in
                    Button { choose(item) } label: {
                        Text(item.replacement).font(.system(size: 14))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(hovered == item.replacement ? Color.accentColor.opacity(0.13) : .clear,
                                        in: RoundedRectangle(cornerRadius: 5))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    .onHover { inside in
                        if inside {
                            hovered = item.replacement
                            preview(item.range)
                        } else if hovered == item.replacement {
                            hovered = nil
                            preview(nil)
                        }
                    }
                }
            }
        }
        .padding(5).frame(width: 232, alignment: .leading)
        .task(id: attempt) {
            loading = true
            message = nil
            needsProvider = false
            do {
                let result = try await load(word)
                try Task.checkCancellation()
                choices = result
            } catch {
                guard !Task.isCancelled else { return }
                if error is WordSuggestionsError {
                    message = "Для этого языка выберите сервис. Он получит слово и фрагмент перевода."
                    needsProvider = true
                } else {
                    message = TranslationError.message(for: error)
                }
            }
            loading = false
        }
    }
}
