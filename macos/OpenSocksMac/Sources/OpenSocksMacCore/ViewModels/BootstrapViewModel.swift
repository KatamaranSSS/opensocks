import Combine
import Foundation

@MainActor
public final class BootstrapViewModel: ObservableObject {
    @Published public var baseURLString: String
    @Published public var clientToken: String
    @Published public private(set) var username: String = ""
    @Published public private(set) var configs: [ClientConfig] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var statusMessage: String = ""
    @Published public private(set) var errorMessage: String?

    private let apiClient: OpenSocksAPIClientProtocol
    private let tokenStore: ClientTokenStore
    private let baseURLStore: APIBaseURLStore

    public init(
        apiClient: OpenSocksAPIClientProtocol,
        tokenStore: ClientTokenStore,
        baseURLStore: APIBaseURLStore
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.baseURLStore = baseURLStore
        self.baseURLString = baseURLStore.readBaseURL() ?? "http://127.0.0.1:18000"
        self.clientToken = (try? tokenStore.readToken()) ?? ""
    }

    public func persistSettings() {
        let trimmedBaseURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        baseURLStore.writeBaseURL(trimmedBaseURL)

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

    private func resolvedBaseURL() throws -> URL {
        let trimmedValue = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedValue), url.scheme != nil, url.host != nil else {
            throw OpenSocksClientError.invalidBaseURL
        }
        return url
    }

    private func resolvedErrorMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return error.localizedDescription
    }
}
