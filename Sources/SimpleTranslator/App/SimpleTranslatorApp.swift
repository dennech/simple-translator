import SwiftUI
import AppKit

@main
struct SimpleTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var preferences = Preferences()
    @State private var store = TranslatorStore()

    init() {
        if CommandLine.arguments.contains("--demo") {
            _store = State(initialValue: TranslatorStore.demonstration())
        }
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--check-provider",
           let provider = Provider(rawValue: CommandLine.arguments[2]) {
            Task.detached { exit(await ConnectionCheck.run(provider: provider)) }
            dispatchMain()
        }
        // Local setup: secret enters over stdin, never argv, logs, preferences or a project file.
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--import-key",
           let provider = Provider(rawValue: CommandLine.arguments[2]) {
            do {
                let data = FileHandle.standardInput.readDataToEndOfFile()
                guard let key = String(data: data, encoding: .utf8), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { exit(2) }
                try Keychain.save(key, for: provider)
                print("Saved in macOS Keychain: \(provider.title)")
                exit(0)
            } catch { fputs("Keychain import failed\n", stderr); exit(1) }
        }
    }

    var body: some Scene {
        Window("Simple Translator", id: "translator") {
            ContentView(store: store, preferences: preferences)
        }
        .defaultSize(width: 940, height: 540)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .help) { }
        }
        Settings { SettingsView(preferences: preferences) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }) {
            existing.activate(options: [])
            NSApp.terminate(nil)
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first(where: { $0.identifier?.rawValue == "translator" || $0.title == "Simple Translator" })?.makeKeyAndOrderFront(nil) }
        return true
    }
}
