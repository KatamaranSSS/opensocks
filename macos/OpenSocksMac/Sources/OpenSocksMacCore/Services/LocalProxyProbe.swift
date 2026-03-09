import Foundation
import Network

public protocol LocalProxyProbeProtocol: Sendable {
    func isListening(on port: Int) async -> Bool
    func waitUntilListening(on port: Int, timeoutNanoseconds: UInt64) async -> Bool
}

public struct LocalProxyProbe: LocalProxyProbeProtocol {
    public init() {}

    public func isListening(on port: Int) async -> Bool {
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "opensocks.local-proxy-probe")
            let connection = NWConnection(
                host: "127.0.0.1",
                port: endpointPort,
                using: .tcp
            )

            final class StateBox {
                var completed = false
            }

            let state = StateBox()

            func finish(_ value: Bool) {
                guard !state.completed else {
                    return
                }
                state.completed = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 1) {
                finish(false)
            }
        }
    }

    public func waitUntilListening(on port: Int, timeoutNanoseconds: UInt64 = 3_000_000_000)
        async -> Bool
    {
        let start = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if await isListening(on: port) {
                return true
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        return await isListening(on: port)
    }
}
