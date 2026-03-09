import Foundation

public struct SystemSOCKSProxyStatus: Equatable, Sendable {
    public let serviceName: String?
    public let enabled: Bool
    public let server: String?
    public let port: Int?

    public init(serviceName: String?, enabled: Bool, server: String?, port: Int?) {
        self.serviceName = serviceName
        self.enabled = enabled
        self.server = server
        self.port = port
    }

    public var isManagedByOpenSocks: Bool {
        enabled && server == "127.0.0.1"
    }
}

public enum SystemProxyManagerError: LocalizedError, Equatable, Sendable {
    case noDefaultNetworkInterface
    case noNetworkServiceForInterface(String)
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noDefaultNetworkInterface:
            return "Could not determine the active macOS network interface"
        case let .noNetworkServiceForInterface(interface):
            return "Could not find a macOS network service for interface \(interface)"
        case let .commandFailed(message):
            return message
        }
    }
}

public protocol SystemProxySnapshotStore: Sendable {
    func readSnapshot() -> SystemSOCKSProxySnapshot?
    func writeSnapshot(_ snapshot: SystemSOCKSProxySnapshot)
    func clearSnapshot()
}

public struct SystemSOCKSProxySnapshot: Codable, Equatable, Sendable {
    public let serviceName: String
    public let enabled: Bool
    public let server: String?
    public let port: Int?

    public init(serviceName: String, enabled: Bool, server: String?, port: Int?) {
        self.serviceName = serviceName
        self.enabled = enabled
        self.server = server
        self.port = port
    }
}

public final class UserDefaultsSystemProxySnapshotStore: SystemProxySnapshotStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(
        defaults: UserDefaults = .standard,
        key: String = "opensocks.client.systemProxySnapshot"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func readSnapshot() -> SystemSOCKSProxySnapshot? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(SystemSOCKSProxySnapshot.self, from: data)
    }

    public func writeSnapshot(_ snapshot: SystemSOCKSProxySnapshot) {
        guard let data = try? encoder.encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    public func clearSnapshot() {
        defaults.removeObject(forKey: key)
    }
}

public protocol SystemProxyManaging: Sendable {
    func currentStatus() async throws -> SystemSOCKSProxyStatus
    func enableLocalSOCKSProxy(port: Int) async throws -> SystemSOCKSProxyStatus
    func disableManagedSOCKSProxy() async throws -> SystemSOCKSProxyStatus
}

public actor MacOSSystemProxyManager: SystemProxyManaging {
    private let snapshotStore: SystemProxySnapshotStore

    public init(snapshotStore: SystemProxySnapshotStore) {
        self.snapshotStore = snapshotStore
    }

    public func currentStatus() async throws -> SystemSOCKSProxyStatus {
        let serviceName = try resolvePrimaryNetworkService()
        return try readSOCKSProxyStatus(for: serviceName)
    }

    public func enableLocalSOCKSProxy(port: Int) async throws -> SystemSOCKSProxyStatus {
        let serviceName = try resolvePrimaryNetworkService()
        let currentStatus = try readSOCKSProxyStatus(for: serviceName)

        if currentStatus.server != "127.0.0.1" || currentStatus.port != port {
            snapshotStore.writeSnapshot(
                SystemSOCKSProxySnapshot(
                    serviceName: serviceName,
                    enabled: currentStatus.enabled,
                    server: currentStatus.server,
                    port: currentStatus.port
                )
            )
        }

        let command = [
            "/usr/sbin/networksetup -setsocksfirewallproxy \(shellQuoted(serviceName)) 127.0.0.1 \(port)",
            "/usr/sbin/networksetup -setproxybypassdomains \(shellQuoted(serviceName)) localhost 127.0.0.1 ::1",
            "/usr/sbin/networksetup -setsocksfirewallproxystate \(shellQuoted(serviceName)) on",
        ].joined(separator: " && ")
        try runPrivilegedShell(command)

        return try readSOCKSProxyStatus(for: serviceName)
    }

    public func disableManagedSOCKSProxy() async throws -> SystemSOCKSProxyStatus {
        if let snapshot = snapshotStore.readSnapshot() {
            if snapshot.enabled, let server = snapshot.server, let port = snapshot.port {
                let command = [
                    "/usr/sbin/networksetup -setsocksfirewallproxy \(shellQuoted(snapshot.serviceName)) \(shellQuoted(server)) \(port)",
                    "/usr/sbin/networksetup -setsocksfirewallproxystate \(shellQuoted(snapshot.serviceName)) on",
                ].joined(separator: " && ")
                try runPrivilegedShell(command)
            } else {
                let command =
                    "/usr/sbin/networksetup -setsocksfirewallproxystate \(shellQuoted(snapshot.serviceName)) off"
                try runPrivilegedShell(command)
            }

            snapshotStore.clearSnapshot()
            return try readSOCKSProxyStatus(for: snapshot.serviceName)
        }

        let serviceName = try resolvePrimaryNetworkService()
        let currentStatus = try readSOCKSProxyStatus(for: serviceName)
        if currentStatus.isManagedByOpenSocks {
            let command =
                "/usr/sbin/networksetup -setsocksfirewallproxystate \(shellQuoted(serviceName)) off"
            try runPrivilegedShell(command)
        }

        return try readSOCKSProxyStatus(for: serviceName)
    }

    private func resolvePrimaryNetworkService() throws -> String {
        let defaultRouteOutput = try runProcess(
            executable: "/usr/sbin/route",
            arguments: ["get", "default"]
        )
        guard let interfaceName = Self.parseDefaultInterface(defaultRouteOutput) else {
            throw SystemProxyManagerError.noDefaultNetworkInterface
        }

        let serviceOrderOutput = try runProcess(
            executable: "/usr/sbin/networksetup",
            arguments: ["-listnetworkserviceorder"]
        )
        guard let serviceName = Self.parseNetworkService(
            from: serviceOrderOutput,
            interfaceName: interfaceName
        ) else {
            throw SystemProxyManagerError.noNetworkServiceForInterface(interfaceName)
        }

        return serviceName
    }

    private func readSOCKSProxyStatus(for serviceName: String) throws -> SystemSOCKSProxyStatus {
        let output = try runProcess(
            executable: "/usr/sbin/networksetup",
            arguments: ["-getsocksfirewallproxy", serviceName]
        )
        return Self.parseSOCKSProxyStatus(from: output, serviceName: serviceName)
    }

    private func runPrivilegedShell(_ command: String) throws {
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"

        _ = try runProcess(
            executable: "/usr/bin/osascript",
            arguments: ["-e", script]
        )
    }

    private func runProcess(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw SystemProxyManagerError.commandFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let stdout = String(
            decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        let stderr = String(
            decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )

        guard process.terminationStatus == 0 else {
            let message = [stderr.trimmingCharacters(in: .whitespacesAndNewlines), stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)]
                .first { !$0.isEmpty } ?? "Command failed"
            throw SystemProxyManagerError.commandFailed(message)
        }

        return stdout
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func parseDefaultInterface(_ output: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("interface:") }?
            .split(separator: " ", omittingEmptySubsequences: true)
            .last
            .map(String.init)
    }

    static func parseNetworkService(from output: String, interfaceName: String) -> String? {
        var currentServiceName: String?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if let serviceName = parseServiceLine(line) {
                currentServiceName = serviceName
                continue
            }

            if line.contains("Device: \(interfaceName)"), let currentServiceName {
                return currentServiceName
            }
        }

        return nil
    }

    static func parseSOCKSProxyStatus(from output: String, serviceName: String) -> SystemSOCKSProxyStatus {
        var enabled = false
        var server: String?
        var port: Int?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("Enabled:") {
                enabled = line.split(separator: ":", maxSplits: 1).last?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare("Yes") == .orderedSame
            } else if line.hasPrefix("Server:") {
                server = line.split(separator: ":", maxSplits: 1).last?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.hasPrefix("Port:") {
                port = line.split(separator: ":", maxSplits: 1).last?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .flatMap(Int.init)
            }
        }

        return SystemSOCKSProxyStatus(
            serviceName: serviceName,
            enabled: enabled,
            server: server,
            port: port
        )
    }

    private static func parseServiceLine(_ line: String) -> String? {
        guard line.hasPrefix("("), let closingIndex = line.firstIndex(of: ")") else {
            return nil
        }

        let suffix = line[line.index(after: closingIndex)...].trimmingCharacters(in: .whitespaces)
        guard !suffix.isEmpty, !suffix.hasPrefix("(Hardware Port:") else {
            return nil
        }

        return suffix.hasPrefix("*")
            ? suffix.dropFirst().trimmingCharacters(in: .whitespaces)
            : suffix
    }
}
