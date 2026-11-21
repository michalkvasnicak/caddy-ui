import ServiceManagement
import SwiftUI

@MainActor
struct LoginItemMenu: View {
    let model: AppModel
    @State private var status = SMAppService.mainApp.status

    var body: some View {
        Button(status == .enabled ? "Disable Launch at Login" : "Launch at Login") {
            updateLoginItem()
        }
        .onAppear { status = SMAppService.mainApp.status }

        if status == .requiresApproval {
            Button("Open Login Items Settings…") {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    private func updateLoginItem() {
        let service = SMAppService.mainApp
        defer { status = service.status }

        do {
            if service.status == .enabled {
                try service.unregister()
            } else if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            } else {
                try service.register()
            }
        } catch {
            model.notice = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }
}
