import SwiftUI
import AppKit

private let translatorWindowID = "translator"

@main
struct SimpleTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var preferences = Preferences()
    @State private var store = TranslatorStore()

    init() {
        if Array(CommandLine.arguments.dropFirst()) == ["--version"] {
            print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
            exit(0)
        }
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
        Window("Simple Translator", id: translatorWindowID) {
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
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)),
                                               name: NSWindow.willCloseNotification, object: nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.identifier?.rawValue == translatorWindowID else { return }
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first(where: { $0.identifier?.rawValue == translatorWindowID || $0.title == "Simple Translator" })?.makeKeyAndOrderFront(nil) }
        return true
    }
}
