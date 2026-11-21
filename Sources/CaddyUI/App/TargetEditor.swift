import SwiftUI

struct TargetDraft: Identifiable {
    let id = UUID()
    let originalHost: String?
    var name: String
    var upstream: String

    var domainSuffix: String {
        // Preserve bare localhost when editing a target that already uses it.
        originalHost == "localhost" && cleanName.lowercased() == "localhost" ? "" : ProxyTarget.localSuffix
    }

    var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var host: String { cleanName + domainSuffix }

    init(target: ProxyTarget? = nil) {
        let host = target?.host ?? ""
        originalHost = target?.host
        name = host.hasSuffix(ProxyTarget.localSuffix) ? String(host.dropLast(ProxyTarget.localSuffix.count)) : host
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
                LabeledContent("Hostname") {
                    HStack(spacing: 4) {
                        TextField("Hostname", text: $draft.name, prompt: Text("app"))
                            .labelsHidden()
                        Text("\(draft.domainSuffix):\(String(CaddyConfiguration.port))")
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
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
                    .disabled(saving || !model.canChange || draft.cleanName.isEmpty || draft.upstream.isEmpty)
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
