import Foundation

struct TargetStore {
    let file: URL

    func load() throws -> [ProxyTarget] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let saved = try JSONDecoder().decode([ProxyTarget].self, from: Data(contentsOf: file))
        let validated = try saved.map { try ProxyTarget(host: $0.host, upstream: $0.upstream) }
        guard Set(validated.map(\.host)).count == validated.count else {
            throw AppError("The saved targets contain duplicate hostnames.")
        }
        return validated.sorted { $0.host < $1.host }
    }

    func save(_ targets: [ProxyTarget]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(targets).write(to: file, options: .atomic)
    }
}
