import Darwin
import Foundation

@MainActor
final class CaddyProcess {
    private var process: Process?
    private let configURL: URL
    let logURL: URL
    private let adminSocket: URL

    init(directory: URL) {
        configURL = directory.appendingPathComponent("caddy.json")
        logURL = directory.appendingPathComponent("caddy.log")
        let suffix = UUID().uuidString.prefix(8)
        adminSocket = directory.appendingPathComponent("admin-\(suffix).sock")
    }

    func start(targets: [ProxyTarget], onExit: @escaping @MainActor (Int32) -> Void) throws {
        try writeConfig(targets)
        let running = try command(["run", "--config", configURL.path])
        running.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor in
                guard let self else { return }
                self.process = nil
                try? FileManager.default.removeItem(at: self.adminSocket)
                onExit(status)
            }
        }
        try running.run()
        process = running
    }

    func reload(targets: [ProxyTarget]) async throws {
        try writeConfig(targets)
        let reload = try command(["reload", "--config", configURL.path, "--address", "unix/\(adminSocket.path)"])
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            reload.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            do {
                try reload.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        guard status == 0 else { throw AppError("Caddy rejected the reload. See \(logURL.path).") }
    }

    func stop() {
        if let process, process.isRunning {
            process.terminate()
        }
    }

    private func writeConfig(_ targets: [ProxyTarget]) throws {
        try CaddyConfiguration.encode(targets: targets, adminSocket: adminSocket).write(
            to: configURL, options: .atomic
        )
    }

    private func command(_ arguments: [String]) throws -> Process {
        let candidates = ["/opt/homebrew/bin/caddy", "/usr/local/bin/caddy"]
        guard let binary = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw AppError("Caddy was not found. Install it with brew install caddy.")
        }

        let descriptor = open(logURL.path, O_CREAT | O_WRONLY | O_APPEND | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw AppError("Could not open \(logURL.path).") }
        let log = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)

        let command = Process()
        command.executableURL = URL(fileURLWithPath: binary)
        command.arguments = arguments
        command.standardInput = FileHandle.nullDevice
        command.standardOutput = log
        command.standardError = log
        return command
    }
}
