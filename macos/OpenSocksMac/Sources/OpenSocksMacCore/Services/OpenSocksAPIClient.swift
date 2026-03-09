import Foundation

public enum OpenSocksClientError: LocalizedError, Equatable {
    case invalidBaseURL
    case missingClientToken
    case unauthorized
    case invalidResponse
    case server(message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid API base URL"
        case .missingClientToken:
            return "Client token is required"
        case .unauthorized:
            return "Client token was rejected by the API"
        case .invalidResponse:
            return "API returned an unexpected response"
        case let .server(message):
            return message
        }
    }
}

public protocol OpenSocksAPIClientProtocol {
    func fetchBootstrap(baseURL: URL, clientToken: String) async throws -> ClientBootstrap
}

private struct APIErrorResponse: Decodable {
    let detail: String
}

public final class OpenSocksAPIClient: OpenSocksAPIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    public func fetchBootstrap(baseURL: URL, clientToken: String) async throws -> ClientBootstrap {
        let request = try Self.makeBootstrapRequest(baseURL: baseURL, clientToken: clientToken)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenSocksClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try decoder.decode(ClientBootstrap.self, from: data)
        case 401:
            throw OpenSocksClientError.unauthorized
        default:
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw OpenSocksClientError.server(message: apiError.detail)
            }
            throw OpenSocksClientError.server(message: "API error \(httpResponse.statusCode)")
        }
    }

    public static func makeBootstrapRequest(
        baseURL: URL,
        clientToken: String
    ) throws -> URLRequest {
        let trimmedToken = clientToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw OpenSocksClientError.missingClientToken
        }

        let endpoint = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("client")
            .appendingPathComponent("bootstrap")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
