import Foundation

public struct ClientBootstrap: Codable, Equatable, Sendable {
    public let userID: UUID
    public let username: String
    public let configs: [ClientConfig]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case configs
    }

    public init(userID: UUID, username: String, configs: [ClientConfig]) {
        self.userID = userID
        self.username = username
        self.configs = configs
    }
}

public struct ClientConfig: Codable, Equatable, Identifiable, Sendable {
    public let accessKeyID: UUID
    public let name: String
    public let server: String
    public let serverPort: Int
    public let method: String
    public let password: String
    public let tag: String
    public let ssURL: String

    public var id: UUID {
        accessKeyID
    }

    enum CodingKeys: String, CodingKey {
        case accessKeyID = "access_key_id"
        case name
        case server
        case serverPort = "server_port"
        case method
        case password
        case tag
        case ssURL = "ss_url"
    }

    public init(
        accessKeyID: UUID,
        name: String,
        server: String,
        serverPort: Int,
        method: String,
        password: String,
        tag: String,
        ssURL: String
    ) {
        self.accessKeyID = accessKeyID
        self.name = name
        self.server = server
        self.serverPort = serverPort
        self.method = method
        self.password = password
        self.tag = tag
        self.ssURL = ssURL
    }
}
