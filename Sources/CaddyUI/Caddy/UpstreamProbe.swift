import Foundation
import Network

enum UpstreamProbe {
    static func isReachable(_ upstream: String) async -> Bool {
        let parts = upstream.split(separator: ":")
        guard parts.count == 2, let number = UInt16(parts[1]),
              let port = NWEndpoint.Port(rawValue: number) else { return false }

        let connection = NWConnection(host: NWEndpoint.Host(String(parts[0])), port: port, using: .tcp)
        let (results, continuation) = AsyncStream<Bool>.makeStream()
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                continuation.yield(true)
                continuation.finish()
            case .failed, .cancelled:
                continuation.finish()
            default:
                break
            }
        }

        let timeout = Task {
            try? await Task.sleep(for: .seconds(1))
            continuation.finish()
        }
        defer {
            timeout.cancel()
            connection.cancel()
        }

        connection.start(queue: .global(qos: .utility))
        var iterator = results.makeAsyncIterator()
        return await iterator.next() ?? false
    }
}
