import Foundation

public enum ShadowsocksLocalRunnerError: LocalizedError, Equatable, Sendable {
    case invalidLocalSocksPort
    case emptyBinaryPath
    case missingBinary(path: String)
    case launchFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidLocalSocksPort:
            return "Local SOCKS5 port must be a valid port number"
        case .emptyBinaryPath:
            return "Path to sslocal binary is required"
        case let .missingBinary(path):
            return "sslocal binary not found at \(path)"
        case let .launchFailed(message):
            return message
        }
    }
}

@MainActor
public protocol ShadowsocksLocalRunnerProtocol: AnyObject {
    var activeAccessKeyID: UUID? { get }
    var latestLogOutput: String { get }
    var onTermination: ((Int32) -> Void)? { get set }

    func start(config: ClientConfig, binaryPath: String, localSocksPort: Int) throws
    func stop()
}

@MainActor
public final class ShadowsocksLocalRunner: ShadowsocksLocalRunnerProtocol {
    public private(set) var activeAccessKeyID: UUID?
    public private(set) var latestLogOutput = ""
    public var onTermination: ((Int32) -> Void)?

    private var process: Process?
    private var outputPipe: Pipe?
    private let fileManager: FileManager
    private var manualStopRequested = false

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func start(config: ClientConfig, binaryPath: String, localSocksPort: Int) throws {
        guard (1...65535).contains(localSocksPort) else {
            throw ShadowsocksLocalRunnerError.invalidLocalSocksPort
        }

        stop()
        latestLogOutput = ""
        manualStopRequested = false

        let trimmedBinaryPath = binaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBinaryPath.isEmpty else {
            throw ShadowsocksLocalRunnerError.emptyBinaryPath
        }

        let process = Process()
        let pipe = Pipe()
        let commandArguments = [
            "-b", "127.0.0.1",
            "-l", "\(localSocksPort)",
            "-s", config.server,
            "-p", "\(config.serverPort)",
            "-k", config.password,
            "-m", config.method,
        ]

        if trimmedBinaryPath.contains("/") {
            guard fileManager.isExecutableFile(atPath: trimmedBinaryPath) else {
                throw ShadowsocksLocalRunnerError.missingBinary(path: trimmedBinaryPath)
            }
            process.executableURL = URL(fileURLWithPath: trimmedBinaryPath)
            process.arguments = commandArguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [trimmedBinaryPath] + commandArguments
        }

        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { [weak self] terminatedProcess in
            Task { @MainActor in
                self?.cleanupAfterTermination(status: terminatedProcess.terminationStatus)
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }

            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in
                self?.appendLog(text)
            }
        }

        do {
            try process.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            throw ShadowsocksLocalRunnerError.launchFailed(message: error.localizedDescription)
        }

        self.process = process
        self.outputPipe = pipe
        self.activeAccessKeyID = config.id
    }

    public func stop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        if let process, process.isRunning {
            manualStopRequested = true
            process.terminate()
        }
        process = nil
        outputPipe = nil
        activeAccessKeyID = nil
    }

    private func appendLog(_ text: String) {
        latestLogOutput += text
        if latestLogOutput.count > 4000 {
            latestLogOutput = String(latestLogOutput.suffix(4000))
        }
    }

    private func cleanupAfterTermination(status: Int32) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        activeAccessKeyID = nil
        let resolvedStatus: Int32 = manualStopRequested ? 0 : status
        manualStopRequested = false
        onTermination?(resolvedStatus)
    }
}
