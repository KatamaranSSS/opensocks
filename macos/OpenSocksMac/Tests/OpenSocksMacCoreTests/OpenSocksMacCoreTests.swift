import XCTest
@testable import OpenSocksMacCore

final class OpenSocksMacCoreTests: XCTestCase {
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
            baseURLStore: InMemoryBaseURLStore()
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
            baseURLStore: InMemoryBaseURLStore()
        )
        viewModel.baseURLString = "http://127.0.0.1:18000"
        viewModel.clientToken = "bad-token"

        await viewModel.fetchBootstrap()

        XCTAssertEqual(viewModel.configs, [])
        XCTAssertEqual(viewModel.errorMessage, "Client token was rejected by the API")
    }
}

private struct MockAPIClient: OpenSocksAPIClientProtocol {
    let result: Result<ClientBootstrap, Error>

    func fetchBootstrap(baseURL: URL, clientToken: String) async throws -> ClientBootstrap {
        _ = baseURL
        _ = clientToken
        return try result.get()
    }
}

private final class InMemoryTokenStore: ClientTokenStore {
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

private final class InMemoryBaseURLStore: APIBaseURLStore {
    private var baseURL: String?

    func readBaseURL() -> String? {
        baseURL
    }

    func writeBaseURL(_ value: String) {
        baseURL = value
    }
}
