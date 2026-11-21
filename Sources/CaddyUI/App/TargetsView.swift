import SwiftUI

@MainActor
struct TargetsView: View {
    let model: AppModel

    @State private var selectedHost: String?
    @State private var editor: TargetDraft?
    @State private var targetToRemove: ProxyTarget?

    private var selection: ProxyTarget? {
        model.targets.first { $0.host == selectedHost }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selectedHost) {
                ForEach(model.targets) { target in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(CaddyConfiguration.address(for: target.host)).font(.headline)
                        Text(target.upstream).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(target.host)
                }
            }
            .overlay {
                if model.targets.isEmpty {
                    ContentUnavailableView("No Targets", systemImage: "server.rack",
                                           description: Text("Add a hostname and its upstream to get started."))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Caddy: \(model.status.rawValue) · HTTPS on port \(String(CaddyConfiguration.port))")
                    .foregroundStyle(.secondary)
                if let notice = model.notice {
                    Text(notice)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                if model.needsReload {
                    Button("Retry Applying Saved Targets", action: retryReload)
                        .disabled(!model.canChange)
                }
            }
            .font(.callout)
            .padding()
        }
        .frame(minWidth: 450, minHeight: 260)
        .toolbar {
            Button {
                editor = TargetDraft()
            } label: {
                Label("Add Target", systemImage: "plus")
            }
            .disabled(!model.canChange)

            Button {
                if let selection { editor = TargetDraft(target: selection) }
            } label: {
                Label("Edit Target", systemImage: "pencil")
            }
            .disabled(selection == nil || !model.canChange)

            Button {
                targetToRemove = selection
            } label: {
                Label("Remove Target", systemImage: "minus")
            }
            .disabled(selection == nil || !model.canChange)
        }
        .sheet(item: $editor) { draft in
            TargetEditor(model: model, draft: draft) { host in
                selectedHost = host
            }
        }
        .alert("Remove Target?", isPresented: showingRemoval, presenting: targetToRemove) { target in
            Button("Remove", role: .destructive) { remove(target) }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text("Remove the reverse proxy for \(target.host)?")
        }
    }

    private var showingRemoval: Binding<Bool> {
        Binding(get: { targetToRemove != nil }, set: { if !$0 { targetToRemove = nil } })
    }

    private func remove(_ target: ProxyTarget) {
        Task {
            do {
                model.notice = try await model.remove(host: target.host)
                selectedHost = nil
            } catch {
                model.notice = error.localizedDescription
            }
        }
    }

    private func retryReload() {
        Task {
            do {
                try await model.applySavedTargets()
                model.notice = nil
            } catch {
                model.notice = error.localizedDescription
            }
        }
    }
}
