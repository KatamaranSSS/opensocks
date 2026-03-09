import Darwin
import Foundation

public protocol LocalProxyProbeProtocol: Sendable {
    func isListening(on port: Int) async -> Bool
    func waitUntilListening(on port: Int, timeoutNanoseconds: UInt64) async -> Bool
}

public extension LocalProxyProbeProtocol {
    func waitUntilListening(on port: Int) async -> Bool {
        await waitUntilListening(on: port, timeoutNanoseconds: 3_000_000_000)
    }
}

public struct LocalProxyProbe: LocalProxyProbeProtocol {
    public init() {}

    public func isListening(on port: Int) async -> Bool {
        guard (1...65535).contains(port) else {
            return false
        }

        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            return false
        }
        defer {
            close(socketFD)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(
                    socketFD,
                    sockaddrPointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                ) == 0
            }
        }
    }

    public func waitUntilListening(on port: Int, timeoutNanoseconds: UInt64) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if await isListening(on: port) {
                return true
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        return await isListening(on: port)
    }
}
