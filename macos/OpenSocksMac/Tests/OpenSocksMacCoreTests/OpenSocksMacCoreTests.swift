import XCTest
@testable import OpenSocksMacCore

final class OpenSocksMacCoreTests: XCTestCase {
    func testShadowsocksRunnerBuildsCurrentCliArguments() {
        let config = ClientConfig(
            accessKeyID: UUID(uuidString: "4443f193-4a1b-4cf5-9900-554ac3b333ac")!,
            name: "sergei-spb-key",
            server: "109.71.246.216",
            serverPort: 8389,
            method: "chacha20-ietf-poly1305",
            password: "secret",
            tag: "sergei-sergei-spb-key",
            ssURL: "ss://example"
        )

        let arguments = ShadowsocksLocalRunner.makeCommandArguments(
            config: config,
            localSocksPort: 1086
        )

        XCTAssertEqual(
            arguments,
            [
                "-b", "127.0.0.1:1086",
                "-s", "109.71.246.216:8389",
                "-k", "secret",
                "-m", "chacha20-ietf-poly1305",
            ]
        )
    }

    func testMakeBootstrapRequestUsesExpectedPathAndToken() throws {
        let baseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:18000"))

        let request = try OpenSocksAPIClient.makeBootstrapRequest(
            baseURL: baseURL,
            clientToken: "client-token"
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "http://127.0.0.1:18000/api/v1/client/bootstrap"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer client-token"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    @MainActor
    func testFetchBootstrapLoadsConfigs() async {
        let expectedConfig = ClientConfig(
            accessKeyID: UUID(uuidString: "4443f193-4a1b-4cf5-9900-554ac3b333ac")!,
            name: "sergei-spb-key",
            server: "109.71.246.216",
            serverPort: 8389,
            method: "chacha20-ietf-poly1305",
            password: "secret",
            tag: "sergei-sergei-spb-key",
            ssURL: "ss://example"
        )
        let bootstrap = ClientBootstrap(
            userID: UUID(uuidString: "12f77b95-3d7c-4e1e-a59c-ad1fe4382a15")!,
            username: "sergei",
            configs: [expectedConfig]
        )
        let viewModel = BootstrapViewModel(
            apiClient: MockAPIClient(result: .success(bootstrap)),
            tokenStore: InMemoryTokenStore(),
            baseURLStore: InMemoryBaseURLStore(),
            localRunner: MockLocalRunner(),
            proxyProbe: MockLocalProxyProbe(isListening: true),
            systemProxyManager: MockSystemProxyManager()
        )
        viewModel.baseURLString = "http://127.0.0.1:18000"
        viewModel.clientToken = "client-token"

        await viewModel.fetchBootstrap()

        XCTAssertEqual(viewModel.username, "sergei")
        XCTAssertEqual(viewModel.configs, [expectedConfig])
        XCTAssertEqual(viewModel.statusMessage, "Loaded 1 config(s)")
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testFetchBootstrapRejectsUnauthorizedToken() async {
        let viewModel = BootstrapViewModel(
            apiClient: MockAPIClient(result: .failure(OpenSocksClientError.unauthorized)),
            tokenStore: InMemoryTokenStore(),
            baseURLStore: InMemoryBaseURLStore(),
            localRunner: MockLocalRunner(),
            proxyProbe: MockLocalProxyProbe(isListening: false),
            systemProxyManager: MockSystemProxyManager()
        )
        viewModel.baseURLString = "http://127.0.0.1:18000"
        viewModel.clientToken = "bad-token"

        await viewModel.fetchBootstrap()

        XCTAssertEqual(viewModel.configs, [])
        XCTAssertEqual(viewModel.errorMessage, "Client token was rejected by the API")
    }

    @MainActor
    func testConnectUsesSelectedConfig() async {
        let config = ClientConfig(
            accessKeyID: UUID(uuidString: "4443f193-4a1b-4cf5-9900-554ac3b333ac")!,
            name: "sergei-spb-key",
            server: "109.71.246.216",
            serverPort: 8389,
            method: "chacha20-ietf-poly1305",
            password: "secret",
            tag: "sergei-sergei-spb-key",
            ssURL: "ss://example"
        )
        let runner = MockLocalRunner()
        let emptyBootstrap = ClientBootstrap(
            userID: UUID(),
            username: "",
            configs: []
        )
        let viewModel = BootstrapViewModel(
            apiClient: MockAPIClient(result: .success(emptyBootstrap)),
            tokenStore: InMemoryTokenStore(),
            baseURLStore: InMemoryBaseURLStore(),
            localRunner: runner,
            proxyProbe: MockLocalProxyProbe(isListening: true),
            systemProxyManager: MockSystemProxyManager()
        )
        viewModel.proxyBinaryPath = "/opt/homebrew/bin/sslocal"
        viewModel.localSocksPort = "1086"

        await viewModel.connect(config: config)

        XCTAssertEqual(runner.startedConfigID, config.id)
        XCTAssertEqual(viewModel.activeAccessKeyID, config.id)
        XCTAssertTrue(viewModel.isLocalProxyListening)
        XCTAssertEqual(
            viewModel.proxyStatusMessage,
            "Connected via sergei-spb-key on socks5://127.0.0.1:1086"
        )
    }

    @MainActor
    func testConnectRejectsInvalidPort() async {
        let config = ClientConfig(
            accessKeyID: UUID(uuidString: "4443f193-4a1b-4cf5-9900-554ac3b333ac")!,
            name: "sergei-spb-key",
            server: "109.71.246.216",
            serverPort: 8389,
            method: "chacha20-ietf-poly1305",
            password: "secret",
            tag: "sergei-sergei-spb-key",
            ssURL: "ss://example"
        )
        let emptyBootstrap = ClientBootstrap(
            userID: UUID(),
            username: "",
            configs: []
        )
        let viewModel = BootstrapViewModel(
            apiClient: MockAPIClient(result: .success(emptyBootstrap)),
            tokenStore: InMemoryTokenStore(),
            baseURLStore: InMemoryBaseURLStore(),
            localRunner: MockLocalRunner(),
            proxyProbe: MockLocalProxyProbe(isListening: false),
            systemProxyManager: MockSystemProxyManager()
        )
        viewModel.localSocksPort = "abc"

        await viewModel.connect(config: config)

        XCTAssertNil(viewModel.activeAccessKeyID)
        XCTAssertEqual(
            viewModel.proxyErrorMessage,
            "Local SOCKS5 port must be a valid port number"
        )
    }

    @MainActor
    func testConnectRejectsAlreadyListeningPort() async {
        let config = ClientConfig(
            accessKeyID: UUID(uuidString: "4443f193-4a1b-4cf5-9900-554ac3b333ac")!,
            name: "sergei-spb-key",
            server: "109.71.246.216",
            serverPort: 8389,
            method: "chacha20-ietf-poly1305",
            password: "secret",
            tag: "sergei-sergei-spb-key",
            ssURL: "ss://example"
        )
        let runner = MockLocalRunner()
        let emptyBootstrap = ClientBootstrap(
            userID: UUID(),
            username: "",
            configs: []
        )
        let viewModel = BootstrapViewModel(
            apiClient: MockAPIClient(result: .success(emptyBootstrap)),
            tokenStore: InMemoryTokenStore(),
            baseURLStore: InMemoryBaseURLStore(),
            localRunner: runner,
            proxyProbe: MockLocalProxyProbe(isListening: true),
            systemProxyManager: MockSystemProxyManager()
        )
        viewModel.localSocksPort = "1086"

        await viewModel.connect(config: config)

        XCTAssertNil(runner.startedConfigID)
        XCTAssertNil(viewModel.activeAccessKeyID)
        XCTAssertTrue(viewModel.isLocalProxyListening)
        XCTAssertEqual(
            viewModel.proxyStatusMessage,
            "Local proxy is already listening on socks5://127.0.0.1:1086"
        )
    }

    @MainActor
    func testConnectEnablesSystemProxyWhenRequested() async {
        let config = ClientConfig(
            accessKeyID: UUID(uuidString: "4443f193-4a1b-4cf5-9900-554ac3b333ac")!,
            name: "sergei-spb-key",
            server: "109.71.246.216",
            serverPort: 8389,
            method: "chacha20-ietf-poly1305",
            password: "secret",
            tag: "sergei-sergei-spb-key",
            ssURL: "ss://example"
        )
        let runner = MockLocalRunner()
        let proxyManager = MockSystemProxyManager(
            enableStatus: SystemSOCKSProxyStatus(
                serviceName: "Wi-Fi",
                enabled: true,
                server: "127.0.0.1",
                port: 1086
            )
        )
        let emptyBootstrap = ClientBootstrap(userID: UUID(), username: "", configs: [])
        let viewModel = BootstrapViewModel(
            apiClient: MockAPIClient(result: .success(emptyBootstrap)),
            tokenStore: InMemoryTokenStore(),
            baseURLStore: InMemoryBaseURLStore(),
            localRunner: runner,
            proxyProbe: MockLocalProxyProbe(isListening: true),
            systemProxyManager: proxyManager
        )
        viewModel.proxyBinaryPath = "/opt/homebrew/bin/sslocal"
        viewModel.localSocksPort = "1086"
        viewModel.autoConfigureSystemProxy = true

        await viewModel.connect(config: config)

        let enabledPort = await proxyManager.enabledPort
        XCTAssertEqual(enabledPort, 1086)
        XCTAssertTrue(viewModel.isSystemProxyEnabled)
    }
}

private struct MockAPIClient: OpenSocksAPIClientProtocol {
    let result: Result<ClientBootstrap, OpenSocksClientError>

    func fetchBootstrap(baseURL: URL, clientToken: String) async throws -> ClientBootstrap {
        _ = baseURL
        _ = clientToken
        return try result.get()
    }
}

private final class InMemoryTokenStore: ClientTokenStore, @unchecked Sendable {
    private var token: String?

    func readToken() throws -> String? {
        token
    }

    func writeToken(_ token: String) throws {
        self.token = token
    }

    func deleteToken() throws {
        token = nil
    }
}

private final class InMemoryBaseURLStore: APIBaseURLStore, @unchecked Sendable {
    private var baseURL: String?
    private var proxyBinaryPath: String?
    private var localSocksPort: String?
    private var autoConfigureSystemProxy = true

    func readBaseURL() -> String? {
        baseURL
    }

    func writeBaseURL(_ value: String) {
        baseURL = value
    }

    func readProxyBinaryPath() -> String? {
        proxyBinaryPath
    }

    func writeProxyBinaryPath(_ value: String) {
        proxyBinaryPath = value
    }

    func readLocalSocksPort() -> String? {
        localSocksPort
    }

    func writeLocalSocksPort(_ value: String) {
        localSocksPort = value
    }

    func readAutoConfigureSystemProxy() -> Bool {
        autoConfigureSystemProxy
    }

    func writeAutoConfigureSystemProxy(_ value: Bool) {
        autoConfigureSystemProxy = value
    }
}

@MainActor
private final class MockLocalRunner: ShadowsocksLocalRunnerProtocol {
    var activeAccessKeyID: UUID?
    var latestLogOutput = ""
    var onTermination: ((Int32) -> Void)?
    var startedConfigID: UUID?

    func start(config: ClientConfig, binaryPath: String, localSocksPort: Int) throws {
        _ = binaryPath
        _ = localSocksPort
        activeAccessKeyID = config.id
        startedConfigID = config.id
    }

    func stop() {
        activeAccessKeyID = nil
    }
}

private struct MockLocalProxyProbe: LocalProxyProbeProtocol {
    let isListening: Bool

    func isListening(on port: Int) async -> Bool {
        _ = port
        return isListening
    }

    func waitUntilListening(on port: Int, timeoutNanoseconds: UInt64) async -> Bool {
        _ = timeoutNanoseconds
        return await isListening(on: port)
    }
}

private actor MockSystemProxyManager: SystemProxyManaging {
    private(set) var enabledPort: Int?
    private let enableStatus: SystemSOCKSProxyStatus
    private let disableStatus: SystemSOCKSProxyStatus
    private let current: SystemSOCKSProxyStatus

    init(
        current: SystemSOCKSProxyStatus = SystemSOCKSProxyStatus(
            serviceName: "Wi-Fi",
            enabled: false,
            server: nil,
            port: nil
        ),
        enableStatus: SystemSOCKSProxyStatus = SystemSOCKSProxyStatus(
            serviceName: "Wi-Fi",
            enabled: false,
            server: nil,
            port: nil
        ),
        disableStatus: SystemSOCKSProxyStatus = SystemSOCKSProxyStatus(
            serviceName: "Wi-Fi",
            enabled: false,
            server: nil,
            port: nil
        )
    ) {
        self.current = current
        self.enableStatus = enableStatus
        self.disableStatus = disableStatus
    }

    func currentStatus() async throws -> SystemSOCKSProxyStatus {
        current
    }

    func enableLocalSOCKSProxy(port: Int) async throws -> SystemSOCKSProxyStatus {
        enabledPort = port
        return enableStatus
    }

    func disableManagedSOCKSProxy() async throws -> SystemSOCKSProxyStatus {
        disableStatus
    }
}
