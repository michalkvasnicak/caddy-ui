import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Status: String {
        case stopped = "Stopped"
        case running = "Running"
        case stopping = "Stopping"
    }

    var notice: String?
    private(set) var targets: [ProxyTarget] = []
    private(set) var status: Status = .stopped
    private(set) var ready = false
    private(set) var isReloading = false
    private(set) var needsReload = false

    let directory: URL
    private let store: TargetStore
    private let caddy: CaddyProcess

    init(directory: URL) {
        self.directory = directory
        store = TargetStore(file: directory.appendingPathComponent("targets.json"))
        caddy = CaddyProcess(directory: directory)
    }

    var canChange: Bool { ready && !isReloading && status != .stopping }

    func load() throws {
        targets = try store.load()
        ready = true
    }

    func start() throws {
        try requireAvailable()
        guard status == .stopped else { return }

        try caddy.start(targets: targets) { [weak self] exitCode in
            guard let self else { return }
            let unexpected = self.status != .stopping
            self.status = .stopped
            self.needsReload = false
            if unexpected {
                self.notice = "Caddy exited (status \(exitCode)). See \(self.caddy.logURL.path)."
            }
        }
        status = .running
    }

    func stop() throws {
        try requireAvailable()
        guard status == .running else { return }
        status = .stopping
        caddy.stop()
    }

    func shutDown() {
        caddy.stop()
    }

    func save(
        host: String, upstream: String, replacing originalHost: String? = nil
    ) async throws -> (host: String, warning: String?) {
        try requireAvailable()
        let target = try ProxyTarget(host: host, upstream: upstream)
        if let originalHost, !targets.contains(where: { $0.host == originalHost }) {
            throw AppError("No target named \(originalHost).")
        }
        var next = targets.filter { $0.host != originalHost }
        guard !next.contains(where: { $0.host == target.host }) else {
            throw AppError("A target named \(target.host) already exists.")
        }
        next.append(target)
        let warning = try await saveTargets(next)
        return (target.host, warning)
    }

    func remove(host: String) async throws -> String? {
        try requireAvailable()
        guard targets.contains(where: { $0.host == host }) else {
            throw AppError("No target named \(host).")
        }
        return try await saveTargets(targets.filter { $0.host != host })
    }

    func applySavedTargets() async throws {
        try requireAvailable()
        guard status == .running else { return }
        isReloading = true
        defer { isReloading = false }
        try await caddy.reload(targets: targets)
        needsReload = false
    }

    private func saveTargets(_ next: [ProxyTarget]) async throws -> String? {
        let sorted = next.sorted { $0.host < $1.host }
        try store.save(sorted)
        targets = sorted

        guard status == .running else { return nil }
        needsReload = true
        do {
            try await applySavedTargets()
            return nil
        } catch {
            return "Targets were saved but not applied to the running Caddy. \(error.localizedDescription)"
        }
    }

    private func requireAvailable() throws {
        guard canChange else { throw AppError("Caddy UI is unavailable or busy. Try again shortly.") }
    }
}
