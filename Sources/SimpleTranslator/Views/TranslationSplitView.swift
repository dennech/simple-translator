import AppKit
import SwiftUI

/// Keep native divider dragging and accessibility while showing only the gap between the panes.
private final class BorderlessSplitView: NSSplitView {
    override var dividerColor: NSColor { .clear }
}

struct TranslationSplitView<Pane: View>: NSViewControllerRepresentable {
    let original: Pane
    let translation: Pane

    func makeNSViewController(context: Context) -> NSSplitViewController {
        let controller = NSSplitViewController()
        let split = BorderlessSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        controller.splitView = split
        for pane in [original, translation] {
            let item = NSSplitViewItem(viewController: NSHostingController(rootView: pane))
            item.minimumThickness = 268
            item.preferredThicknessFraction = 0.5
            controller.addSplitViewItem(item)
        }
        return controller
    }

    func updateNSViewController(_ controller: NSSplitViewController, context: Context) {
        for (item, pane) in zip(controller.splitViewItems, [original, translation]) {
            (item.viewController as? NSHostingController<Pane>)?.rootView = pane
        }
    }
}
