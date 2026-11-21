import SwiftUI

struct TargetDraft: Identifiable {
    let id = UUID()
    let originalHost: String?
    var host: String
    var upstream: String

    init(target: ProxyTarget? = nil) {
        originalHost = target?.host
        host = target?.host ?? ""
        upstream = target?.upstream ?? ""
    }
}

@MainActor
struct TargetEditor: View {
    let model: AppModel
    @State var draft: TargetDraft
    let didSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.originalHost == nil ? "Add Target" : "Edit Target")
                .font(.headline)

            Form {
                TextField("Hostname", text: $draft.host, prompt: Text("app.localhost"))
                TextField("Upstream", text: $draft.upstream, prompt: Text("127.0.0.1:3000"))
            }
            .disabled(saving)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(saving)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(saving || !model.canChange || draft.host.isEmpty || draft.upstream.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
        .interactiveDismissDisabled(saving)
    }

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            do {
                let saved = try await model.save(
                    host: draft.host, upstream: draft.upstream, replacing: draft.originalHost
                )
                model.notice = saved.warning
                didSave(saved.host)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
