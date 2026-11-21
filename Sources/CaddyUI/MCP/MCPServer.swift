import Foundation

enum MCPServer {
    @MainActor
    static func handle(_ data: Data, model: AppModel) async -> Data {
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        } catch {
            return Self.error(id: NSNull(), code: -32700, message: "Parse error.")
        }

        guard let request = value as? [String: Any], request["jsonrpc"] as? String == "2.0",
              let method = request["method"] as? String else {
            return Self.error(id: NSNull(), code: -32600, message: "Invalid request.")
        }

        // Notifications do not receive responses or execute tools.
        guard let id = request["id"] else { return Data() }
        let params = request["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            let version = params["protocolVersion"] as? String ?? ""
            let supported = ["2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"]
            return result(id: id, value: [
                "protocolVersion": supported.contains(version) ? version : "2025-11-25",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "caddy-ui", "version": "0.1.0"]
            ])
        case "caddy-ui/serve":
            guard let host = params["host"] as? String else {
                return Self.error(id: id, code: -32602, message: "Provide a hostname.")
            }
            do {
                let port = try await model.registerLocalUpstream(host: host)
                return result(id: id, value: ["port": port])
            } catch {
                return Self.error(id: id, code: -32000, message: error.localizedDescription)
            }
        case "ping":
            return result(id: id, value: [:])
        case "tools/list":
            return result(id: id, value: ["tools": MCPTool.allCases.map(\.definition)])
        case "tools/call":
            guard let name = params["name"] as? String, let tool = MCPTool(rawValue: name) else {
                return Self.error(id: id, code: -32602, message: "Unknown or missing tool name.")
            }
            do {
                let output = try await tool.call(params["arguments"] as? [String: Any] ?? [:], model: model)
                return toolResult(id: id, text: output, failed: false)
            } catch {
                return toolResult(id: id, text: error.localizedDescription, failed: true)
            }
        default:
            return Self.error(id: id, code: -32601, message: "Method not found.")
        }
    }

    static func error(id: Any, code: Int, message: String) -> Data {
        encode(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
    }

    private static func result(id: Any, value: [String: Any]) -> Data {
        encode(["jsonrpc": "2.0", "id": id, "result": value])
    }

    private static func toolResult(id: Any, text: String, failed: Bool) -> Data {
        result(id: id, value: ["content": [["type": "text", "text": text]], "isError": failed])
    }

    private static func encode(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }
}
