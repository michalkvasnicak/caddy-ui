import Darwin
import Foundation

final class MCPListener {
    private let source: DispatchSourceRead

    init(directory: URL, handle: @escaping @MainActor (Data) async -> Data) throws {
        let lockPath = directory.appendingPathComponent("instance.lock").path
        let lock = open(lockPath, O_CREAT | O_CLOEXEC | O_NOFOLLOW | O_RDWR, 0o600)
        guard lock >= 0 else { throw LocalSocket.failure("Open instance lock") }

        do {
            guard flock(lock, LOCK_EX | LOCK_NB) == 0 else {
                throw AppError("Could not lock the data directory. Is Caddy UI already open?")
            }
            source = try Self.listen(path: directory.appendingPathComponent("mcp.sock").path, handle: handle)
        } catch {
            close(lock)
            throw error
        }

        let descriptor = Int32(source.handle)
        source.setCancelHandler {
            close(descriptor)
            close(lock)
        }
        source.resume()
    }

    deinit {
        source.cancel()
    }

    private static func listen(
        path: String, handle: @escaping @MainActor (Data) async -> Data
    ) throws -> DispatchSourceRead {
        let descriptor = try LocalSocket.openSocket()
        do {
            guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) != -1,
                  fcntl(descriptor, F_SETFL, O_NONBLOCK) != -1 else {
                throw LocalSocket.failure("Configure listener")
            }
            if unlink(path) != 0 && errno != ENOENT { throw LocalSocket.failure("Remove stale MCP socket") }
            let bound = try LocalSocket.withAddress(path) { bind(descriptor, $0, $1) }
            guard bound == 0, Darwin.listen(descriptor, 8) == 0 else {
                throw LocalSocket.failure("Listen on MCP socket")
            }
        } catch {
            close(descriptor)
            throw error
        }

        let queue = DispatchQueue(label: "CaddyUI.MCP")
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler {
            let client = accept(descriptor, nil, nil)
            guard client >= 0 else { return }
            do {
                guard fcntl(client, F_SETFL, 0) != -1 else { throw LocalSocket.failure("Configure client") }
                try LocalSocket.configureStream(client)
                let request = try LocalSocket.readMessage(from: client)
                Task { @MainActor in
                    let response = await handle(request)
                    queue.async {
                        defer { close(client) }
                        try? LocalSocket.writeMessage(response, to: client)
                    }
                }
            } catch {
                close(client)
            }
        }
        return source
    }
}
