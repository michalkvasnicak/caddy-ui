import Darwin
import Foundation

enum LocalSocket {
    static let maxMessageSize = 1024 * 1024

    static func openSocket() throws -> Int32 {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw failure("Create socket") }
        return descriptor
    }

    static func configureStream(_ descriptor: Int32) throws {
        var enabled: Int32 = 1
        var timeout = timeval(tv_sec: 15, tv_usec: 0)
        guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) != -1,
              setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0,
              setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0,
              setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0 else {
            throw failure("Configure socket")
        }
    }

    static func withAddress<T>(
        _ path: String, _ action: (UnsafePointer<sockaddr>, socklen_t) -> T
    ) throws -> T {
        var address = sockaddr_un()
        let pathBytes = path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw AppError("The Application Support path is too long for the MCP socket.")
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            pathBytes.withUnsafeBytes { buffer.copyBytes(from: $0) }
        }
        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                action($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }

    static func readMessage(from descriptor: Int32) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
            if count < 0 && errno == EINTR { continue }
            guard count >= 0 else { throw failure("Read socket") }
            guard count > 0 else { return data }
            guard data.count + count <= maxMessageSize else { throw AppError("MCP message exceeds 1 MiB.") }
            data.append(contentsOf: buffer.prefix(count))
        }
    }

    static func writeMessage(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { buffer in
            guard let bytes = buffer.baseAddress else { return }
            var written = 0
            while written < buffer.count {
                let count = Darwin.write(descriptor, bytes.advanced(by: written), buffer.count - written)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw failure("Write socket") }
                written += count
            }
        }
    }

    static func failure(_ action: String) -> AppError {
        AppError("\(action): \(String(cString: strerror(errno)))")
    }
}
