import Foundation

enum MCPTool: String, CaseIterable {
    case list = "list_targets"
    case add = "add_target"
    case edit = "edit_target"
    case remove = "remove_target"
    case start = "start_caddy"
    case stop = "stop_caddy"

    var definition: [String: Any] {
        let fields: [String: String]
        let description: String
        let host = "Local hostname (localhost or a name ending in .localhost)."
        let upstream = "Upstream hostname or IPv4 address and port, such as 127.0.0.1:3000."

        switch self {
        case .list:
            description = "List saved reverse proxy targets and Caddy status."
            fields = [:]
        case .add:
            description = "Add a reverse proxy target."
            fields = ["host": host, "upstream": upstream]
        case .edit:
            description = "Replace an existing target, optionally changing its hostname."
            fields = ["original_host": "Existing target hostname.", "host": host, "upstream": upstream]
        case .remove:
            description = "Remove a reverse proxy target."
            fields = ["host": host]
        case .start:
            description = "Start the Caddy instance managed by the app."
            fields = [:]
        case .stop:
            description = "Request shutdown of the Caddy instance managed by the app."
            fields = [:]
        }

        return [
            "name": rawValue,
            "description": description,
            "inputSchema": [
                "type": "object",
                "properties": fields.mapValues { ["type": "string", "description": $0] },
                "required": fields.keys.sorted(),
                "additionalProperties": false
            ]
        ]
    }

    @MainActor
    func call(_ arguments: [String: Any], model: AppModel) async throws -> String {
        guard model.ready else { throw AppError(model.notice ?? "Caddy UI is not ready.") }

        func value(_ key: String) throws -> String {
            guard let value = arguments[key] as? String else {
                throw AppError("Provide a string for \(key).")
            }
            return value
        }

        switch self {
        case .list:
            let snapshot = Snapshot(
                targets: model.targets, status: model.status.rawValue, needsReload: model.needsReload
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            guard let json = String(bytes: data, encoding: .utf8) else {
                throw AppError("Could not encode the target list as UTF-8.")
            }
            return json
        case .add:
            let saved = try await model.save(host: value("host"), upstream: value("upstream"))
            return saved.warning ?? "Target added."
        case .edit:
            let saved = try await model.save(
                host: value("host"), upstream: value("upstream"), replacing: value("original_host")
            )
            return saved.warning ?? "Target updated."
        case .remove:
            return try await model.remove(host: value("host")) ?? "Target removed."
        case .start:
            try model.start()
            return "Caddy process is running. It may still be starting."
        case .stop:
            try model.stop()
            return model.status == .stopped ? "Caddy is stopped." : "Caddy is stopping."
        }
    }

    private struct Snapshot: Encodable {
        let targets: [ProxyTarget]
        let status: String
        let needsReload: Bool
    }
}
