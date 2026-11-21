import Foundation

struct ProxyTarget: Codable, Identifiable {
    static let localSuffix = ".localhost"

    var id: String { host }
    let host: String
    let upstream: String

    init(host: String, upstream: String) throws {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let upstream = upstream.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isHostname(host), host == "localhost" || host.hasSuffix(Self.localSuffix) else {
            throw AppError("Use localhost or a hostname ending in .localhost.")
        }

        let parts = upstream.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, Self.isHostname(String(parts[0])),
              parts[1].allSatisfy({ $0.isASCII && $0.isNumber }),
              let port = UInt16(parts[1]), port > 0 else {
            throw AppError("Enter an upstream as hostname:port, for example 127.0.0.1:3000.")
        }

        self.host = host
        self.upstream = "\(parts[0]):\(port)"
    }

    private static func isHostname(_ host: String) -> Bool {
        let label = "[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
        return host.utf8.count <= 253
            && host.range(of: "\\A\(label)(\\.\(label))*\\z", options: .regularExpression) != nil
    }
}
