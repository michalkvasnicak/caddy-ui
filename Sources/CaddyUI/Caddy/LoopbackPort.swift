import Darwin

enum LoopbackPort {
    static func available() throws -> UInt16 {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw AppError("Could not open a socket to allocate a port.") }
        defer { close(descriptor) }

        var address = sockaddr_in()
        let length = socklen_t(MemoryLayout<sockaddr_in>.size)
        address.sin_len = UInt8(length)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        let status = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                guard bind(descriptor, socketAddress, length) == 0 else { return Int32(-1) }
                var actualLength = length
                return getsockname(descriptor, socketAddress, &actualLength)
            }
        }
        guard status == 0 else { throw AppError("Could not allocate a loopback port.") }
        return UInt16(bigEndian: address.sin_port)
    }
}
