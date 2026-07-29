import Foundation
import Security

/// Stores the Claude API key as a generic password in the login keychain.
enum Keychain {
    private static let service = "com.amol.hover.claude-api-key"
    /// Pre-rename service names — read once and migrate.
    private static let legacyServices = [
        "com.amol.feather.claude-api-key",
        "com.amol.context.claude-api-key",
    ]

    static func read() -> String? {
        if let key = read(service: service) {
            return key
        }
        // Migrate a key saved under one of the app's old names.
        for legacy in legacyServices {
            if let key = read(service: legacy) {
                save(key)
                delete(service: legacy)
                return key
            }
        }
        return nil
    }

    static func save(_ key: String) {
        delete(service: service)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: Data(key.utf8),
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func read(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else { return nil }
        return key
    }

    private static func delete(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
