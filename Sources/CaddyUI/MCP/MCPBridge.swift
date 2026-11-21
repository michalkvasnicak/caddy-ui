import Darwin
import Foundation

enum MCPBridge {
    static func run(directory: URL) {
        let path = directory.appendingPathComponent("mcp.sock").path
        while let line = readLine() {
            let request = Data(line.utf8)
            let response: Data
            do {
                response = try exchange(request, path: path)
            } catch {
                guard let fallback = unavailableResponse(for: request) else { continue }
                response = fallback
            }
            if !response.isEmpty {
                FileHandle.standardOutput.write(response)
                FileHandle.standardOutput.write(Data([0x0A]))
            }
        }
    }

    private static func exchange(_ request: Data, path: String) throws -> Data {
        guard request.count <= LocalSocket.maxMessageSize else {
            throw AppError("MCP message exceeds 1 MiB.")
        }
        let descriptor = try LocalSocket.openSocket()
        defer { close(descriptor) }
        try LocalSocket.configureStream(descriptor)
        let connected = try LocalSocket.withAddress(path) { connect(descriptor, $0, $1) }
        guard connected == 0 else { throw LocalSocket.failure("Connect to Caddy UI") }
        try LocalSocket.writeMessage(request, to: descriptor)
        guard shutdown(descriptor, Int32(SHUT_WR)) == 0 else { throw LocalSocket.failure("Finish request") }
        return try LocalSocket.readMessage(from: descriptor)
    }

    private static func unavailableResponse(for request: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: request) as? [String: Any],
              let id = object["id"] else { return nil }
        return MCPServer.error(id: id, code: -32000, message: "Caddy UI is not responding. Open the menu bar app.")
    }
}
