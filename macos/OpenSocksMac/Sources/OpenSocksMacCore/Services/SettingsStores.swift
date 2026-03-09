import Foundation
import Security

public protocol ClientTokenStore: Sendable {
    func readToken() throws -> String?
    func writeToken(_ token: String) throws
    func deleteToken() throws
}

public protocol APIBaseURLStore: Sendable {
    func readBaseURL() -> String?
    func writeBaseURL(_ value: String)
    func readProxyBinaryPath() -> String?
    func writeProxyBinaryPath(_ value: String)
    func readLocalSocksPort() -> String?
    func writeLocalSocksPort(_ value: String)
    func readAutoConfigureSystemProxy() -> Bool
    func writeAutoConfigureSystemProxy(_ value: Bool)
}

public enum TokenStoreError: LocalizedError, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            return "Keychain operation failed with status \(status)"
        case .invalidData:
            return "Stored client token is invalid"
        }
    }
}

public final class KeychainClientTokenStore: ClientTokenStore, @unchecked Sendable {
    private let service: String
    private let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    public func readToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard
                let data = item as? Data,
                let token = String(data: data, encoding: .utf8)
            else {
                throw TokenStoreError.invalidData
            }
            return token
        case errSecItemNotFound:
            return nil
        default:
            throw TokenStoreError.unexpectedStatus(status)
        }
    }

    public func writeToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw TokenStoreError.unexpectedStatus(insertStatus)
            }
            return
        }

        guard updateStatus == errSecSuccess else {
            throw TokenStoreError.unexpectedStatus(updateStatus)
        }
    }

    public func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.unexpectedStatus(status)
        }
    }
}

public final class UserDefaultsBaseURLStore: APIBaseURLStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let baseURLKey: String
    private let proxyBinaryPathKey: String
    private let localSocksPortKey: String
    private let autoConfigureSystemProxyKey: String

    public init(
        defaults: UserDefaults = .standard,
        baseURLKey: String = "opensocks.client.baseURL",
        proxyBinaryPathKey: String = "opensocks.client.proxyBinaryPath",
        localSocksPortKey: String = "opensocks.client.localSocksPort",
        autoConfigureSystemProxyKey: String = "opensocks.client.autoConfigureSystemProxy"
    ) {
        self.defaults = defaults
        self.baseURLKey = baseURLKey
        self.proxyBinaryPathKey = proxyBinaryPathKey
        self.localSocksPortKey = localSocksPortKey
        self.autoConfigureSystemProxyKey = autoConfigureSystemProxyKey
    }

    public func readBaseURL() -> String? {
        defaults.string(forKey: baseURLKey)
    }

    public func writeBaseURL(_ value: String) {
        defaults.set(value, forKey: baseURLKey)
    }

    public func readProxyBinaryPath() -> String? {
        defaults.string(forKey: proxyBinaryPathKey)
    }

    public func writeProxyBinaryPath(_ value: String) {
        defaults.set(value, forKey: proxyBinaryPathKey)
    }

    public func readLocalSocksPort() -> String? {
        defaults.string(forKey: localSocksPortKey)
    }

    public func writeLocalSocksPort(_ value: String) {
        defaults.set(value, forKey: localSocksPortKey)
    }

    public func readAutoConfigureSystemProxy() -> Bool {
        if defaults.object(forKey: autoConfigureSystemProxyKey) == nil {
            return true
        }
        return defaults.bool(forKey: autoConfigureSystemProxyKey)
    }

    public func writeAutoConfigureSystemProxy(_ value: Bool) {
        defaults.set(value, forKey: autoConfigureSystemProxyKey)
    }
}
