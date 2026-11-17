import SwiftUI
import AppKit

struct PlainTextPane: NSViewRepresentable {
    @Binding var text: String
    var editable = true
    var fontSize: CGFloat = 17
    var wordActions: WordActions?

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        let view = editable ? NSTextView(frame: .zero) : TranslationTextView(frame: .zero)
        view.isEditable = editable
        view.isSelectable = true
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = editable
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.drawsBackground = false
        view.font = .systemFont(ofSize: fontSize)
        view.textColor = .labelColor
        view.insertionPointColor = .controlAccentColor
        view.textContainerInset = NSSize(width: 22, height: 20)
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.setAccessibilityLabel(editable ? "Исходный текст" : "Перевод")
        view.delegate = context.coordinator
        scroll.documentView = view
        if editable {
            DispatchQueue.main.async { if view.window?.firstResponder is NSWindow { view.window?.makeFirstResponder(view) } }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? NSTextView else { return }
        (view as? TranslationTextView)?.actions = wordActions
        view.font = .systemFont(ofSize: fontSize)
        view.textColor = .labelColor
        guard view.string != text, !view.hasMarkedText() else { return }
        context.coordinator.isUpdating = true
        if !editable, text.hasPrefix(view.string), let storage = view.textStorage {
            let suffix = String(text.dropFirst(view.string.count))
            storage.append(NSAttributedString(string: suffix, attributes: [.font: NSFont.systemFont(ofSize: fontSize), .foregroundColor: NSColor.labelColor]))
        } else {
            let previousPosition = scroll.contentView.bounds.origin
            let previousSelection = view.selectedRange()
            view.string = text
            if editable || text.isEmpty {
                view.scrollToBeginningOfDocument(nil)
            } else {
                let length = (text as NSString).length
                view.setSelectedRange(NSRange(location: min(previousSelection.location, length), length: 0))
                scroll.contentView.scroll(to: previousPosition)
                scroll.reflectScrolledClipView(scroll.contentView)
            }
        }
        context.coordinator.isUpdating = false
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextPane
        var isUpdating = false
        init(_ parent: PlainTextPane) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let view = notification.object as? NSTextView, !view.hasMarkedText() else { return }
            parent.text = view.string
        }
    }
}
