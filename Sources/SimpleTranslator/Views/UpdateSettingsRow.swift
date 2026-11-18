import Sparkle
import SwiftUI

private enum AppUpdates {
    @MainActor static let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )
}

struct UpdateSettingsRow: View {
    @State private var canCheck = false

    var body: some View {
        HStack {
            Text("Версия " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Проверить обновления") {
                AppUpdates.controller.checkForUpdates(nil)
            }
            .disabled(!canCheck)
        }
        .onReceive(AppUpdates.controller.updater.publisher(for: \.canCheckForUpdates)) { canCheck = $0 }
    }
}
