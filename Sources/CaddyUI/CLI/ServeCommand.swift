import Darwin
import Foundation

enum ServeCommand {
    private static let usage = "Usage: caddy-ui serve [--name <name>]"

    static func run(_ arguments: [String], directory: URL) {
        if arguments == ["help"] || arguments == ["--help"] || arguments == ["-h"]
            || arguments == ["serve", "--help"] || arguments == ["serve", "-h"] {
            print("""
                \(usage)

                Register or update a local HTTPS route and print its upstream port.
                --name <name>  Use https://<name>.localhost:\(CaddyConfiguration.port).
                               Defaults to the current directory name.

                Example: caddy-ui serve --name web → https://web.localhost:\(CaddyConfiguration.port)

                Keep the Caddy UI menu bar app open and start Caddy before using the route.
                """)
            return
        }

        do {
            let host = try hostname(arguments)
            let request = try JSONSerialization.data(withJSONObject: [
                "jsonrpc": "2.0", "id": 1, "method": "caddy-ui/serve", "params": ["host": host]
            ])
            let response = try MCPBridge.exchange(request, directory: directory)
            let reply = try JSONDecoder().decode(Reply.self, from: response)
            guard let port = reply.result?.port else {
                throw AppError(reply.error?.message ?? "Caddy UI did not return a port.")
            }
            print(port)
        } catch {
            let message = "caddy-ui: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func hostname(_ arguments: [String]) throws -> String {
        let name: String
        if arguments == ["serve"] {
            let path = FileManager.default.currentDirectoryPath
            name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
                .replacingOccurrences(of: "[^a-z0-9-]+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        } else if arguments.count == 3, arguments[1] == "--name" {
            name = arguments[2].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } else {
            throw AppError(usage)
        }

        guard !name.isEmpty else { throw AppError("Provide a hostname with --name.") }
        let suffix = ProxyTarget.localSuffix
        return name.hasSuffix(suffix) ? name : name + suffix
    }

    private struct Reply: Decodable {
        struct Result: Decodable {
            let port: UInt16
        }

        struct Failure: Decodable {
            let message: String
        }

        let result: Result?
        let error: Failure?
    }
}
