import Foundation
import Security

enum KeychainStorageError: Error, LocalizedError {
    case operationFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain operation failed with status: \(status)"
        }
    }
}

protocol CredentialsStorage {
    func save<T: Codable>(_ value: T, for key: String) throws
    func load<T: Codable>(_ type: T.Type, for key: String) throws -> T?
    func removeValue(for key: String) throws
}

final class KeychainCredentialsStorage: CredentialsStorage {
    private let service: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(service: String = Bundle.main.bundleIdentifier ?? "com.dikori.app") {
        self.service = service
    }

    func save<T: Codable>(_ value: T, for key: String) throws {
        let data = try encoder.encode(value)
        var query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStorageError.operationFailed(status: status)
        }
    }

    func load<T: Codable>(_ type: T.Type, for key: String) throws -> T? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStorageError.operationFailed(status: status)
        }

        guard let data = result as? Data else {
            throw KeychainStorageError.operationFailed(status: errSecDecode)
        }

        return try decoder.decode(T.self, from: data)
    }

    func removeValue(for key: String) throws {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStorageError.operationFailed(status: status)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
