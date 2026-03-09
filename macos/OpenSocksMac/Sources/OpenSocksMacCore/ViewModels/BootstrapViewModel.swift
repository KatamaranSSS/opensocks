import Combine
import Foundation

@MainActor
public final class BootstrapViewModel: ObservableObject {
    @Published public var baseURLString: String
    @Published public var clientToken: String
    @Published public var proxyBinaryPath: String
    @Published public var localSocksPort: String
    @Published public private(set) var username: String = ""
    @Published public private(set) var configs: [ClientConfig] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var statusMessage: String = ""
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var proxyStatusMessage: String = "Disconnected"
    @Published public private(set) var proxyErrorMessage: String?
    @Published public private(set) var activeAccessKeyID: UUID?
    @Published public private(set) var proxyLogOutput: String = ""

    private let apiClient: OpenSocksAPIClientProtocol
    private let tokenStore: ClientTokenStore
    private let settingsStore: APIBaseURLStore
    private let localRunner: ShadowsocksLocalRunnerProtocol

    public init(
        apiClient: OpenSocksAPIClientProtocol,
        tokenStore: ClientTokenStore,
        baseURLStore: APIBaseURLStore,
        localRunner: ShadowsocksLocalRunnerProtocol
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.settingsStore = baseURLStore
        self.localRunner = localRunner
        let storedBaseURL = baseURLStore.readBaseURL()
        self.baseURLString = Self.resolvedInitialBaseURL(storedBaseURL)
        self.clientToken = (try? tokenStore.readToken()) ?? ""
        self.proxyBinaryPath = baseURLStore.readProxyBinaryPath() ?? Self.defaultProxyBinaryPath()
        self.localSocksPort = baseURLStore.readLocalSocksPort() ?? "1086"

        self.localRunner.onTermination = { [weak self] status in
            guard let self else {
                return
            }

            self.activeAccessKeyID = nil
            self.proxyLogOutput = self.localRunner.latestLogOutput

            if status == 0 {
                self.proxyStatusMessage = "Disconnected"
                self.proxyErrorMessage = nil
                return
            }

            self.proxyStatusMessage = "Disconnected"
            let logOutput = self.localRunner.latestLogOutput.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            self.proxyErrorMessage = logOutput.isEmpty
                ? "sslocal exited with status \(status)"
                : logOutput
        }
    }

    public func persistSettings() {
        let trimmedBaseURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        settingsStore.writeBaseURL(trimmedBaseURL)
        settingsStore.writeProxyBinaryPath(
            proxyBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        settingsStore.writeLocalSocksPort(
            localSocksPort.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let trimmedToken = clientToken.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmedToken.isEmpty {
                try tokenStore.deleteToken()
            } else {
                try tokenStore.writeToken(trimmedToken)
            }
            statusMessage = "Settings saved"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func fetchBootstrap() async {
        isLoading = true
        errorMessage = nil

        do {
            persistSettings()
            let baseURL = try resolvedBaseURL()
            let bootstrap = try await apiClient.fetchBootstrap(
                baseURL: baseURL,
                clientToken: clientToken
            )
            username = bootstrap.username
            configs = bootstrap.configs
            statusMessage = "Loaded \(bootstrap.configs.count) config(s)"
        } catch {
            username = ""
            configs = []
            statusMessage = ""
            errorMessage = resolvedErrorMessage(for: error)
        }

        isLoading = false
    }

    public func connect(config: ClientConfig) {
        proxyErrorMessage = nil

        do {
            persistSettings()
            let socksPort = try resolvedLocalSocksPort()
            try localRunner.start(
                config: config,
                binaryPath: proxyBinaryPath,
                localSocksPort: socksPort
            )
            activeAccessKeyID = config.id
            proxyLogOutput = localRunner.latestLogOutput
            proxyStatusMessage = "Connected via \(config.name) on socks5://127.0.0.1:\(socksPort)"
        } catch {
            activeAccessKeyID = nil
            proxyStatusMessage = "Disconnected"
            proxyErrorMessage = resolvedErrorMessage(for: error)
        }
    }

    public func disconnect() {
        localRunner.stop()
        activeAccessKeyID = nil
        proxyLogOutput = localRunner.latestLogOutput
        proxyStatusMessage = "Disconnected"
        proxyErrorMessage = nil
    }

    public func isActive(config: ClientConfig) -> Bool {
        activeAccessKeyID == config.id
    }

    private func resolvedBaseURL() throws -> URL {
        let trimmedValue = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedValue), url.scheme != nil, url.host != nil else {
            throw OpenSocksClientError.invalidBaseURL
        }
        return url
    }

    private func resolvedLocalSocksPort() throws -> Int {
        let trimmedValue = localSocksPort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmedValue), (1...65535).contains(port) else {
            throw ShadowsocksLocalRunnerError.invalidLocalSocksPort
        }
        return port
    }

    private func resolvedErrorMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return error.localizedDescription
    }

    private static func defaultProxyBinaryPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/sslocal",
            "/usr/local/bin/sslocal",
            "sslocal",
        ]
        let fileManager = FileManager.default

        for candidate in candidates where candidate == "sslocal" || fileManager.isExecutableFile(
            atPath: candidate
        ) {
            return candidate
        }

        return "sslocal"
    }

    private static func resolvedInitialBaseURL(_ storedValue: String?) -> String {
        switch storedValue?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case nil, "", "http://127.0.0.1:18000":
            return defaultAPIBaseURL()
        case let value?:
            return value
        }
    }

    private static func defaultAPIBaseURL() -> String {
        "http://109.71.246.216:18080"
    }
}
