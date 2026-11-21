import AppKit
import SwiftUI

@MainActor
struct MenuContent: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Caddy: \(model.status.rawValue)")

        Button(model.status == .stopped ? "Start Caddy" : "Stop Caddy") {
            do {
                model.notice = nil
                if model.status == .stopped {
                    try model.start()
                } else {
                    try model.stop()
                }
            } catch {
                model.notice = error.localizedDescription
            }
        }
        .disabled(!model.canChange)

        Button("Manage Targets…") {
            openWindow(id: "targets")
            NSApp.activate()
        }

        if model.notice != nil || model.needsReload {
            Text("See Manage Targets for details.")
        }

        Divider()
        Button("Quit Caddy UI") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
