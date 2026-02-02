import Foundation
import Security

/// Manages Gemini API key storage and retrieval from macOS Keychain.
///
/// Uses separate keychain items for Work and Personal contexts:
/// - `InputForge-Work-GeminiKey`
/// - `InputForge-Personal-GeminiKey`
struct KeychainService: Sendable {
    private static let servicePrefix = "InputForge"

    /// Returns the keychain service name for a given project context.
    static func serviceName(for context: ProjectContext) -> String {
        switch context {
        case .work: return "\(servicePrefix)-Work-GeminiKey"
        case .personal: return "\(servicePrefix)-Personal-GeminiKey"
        }
    }

    /// Retrieve the Gemini API key for the given context.
    ///
    /// - Parameter context: Work or Personal context.
    /// - Returns: The API key string, or nil if not stored.
    static func retrieveAPIKey(for context: ProjectContext) -> String? {
        let service = serviceName(for: context)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "GeminiAPIKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Store or update the Gemini API key for the given context.
    ///
    /// - Parameters:
    ///   - key: The API key string.
    ///   - context: Work or Personal context.
    /// - Returns: True if the operation succeeded.
    @discardableResult
    static func storeAPIKey(_ key: String, for context: ProjectContext) -> Bool {
        let service = serviceName(for: context)
        guard let data = key.data(using: .utf8) else { return false }

        // Delete existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "GeminiAPIKey",
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new entry
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "GeminiAPIKey",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete the Gemini API key for the given context.
    ///
    /// - Parameter context: Work or Personal context.
    /// - Returns: True if the key was deleted (or didn't exist).
    @discardableResult
    static func deleteAPIKey(for context: ProjectContext) -> Bool {
        let service = serviceName(for: context)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "GeminiAPIKey",
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if an API key exists for the given context without retrieving it.
    static func hasAPIKey(for context: ProjectContext) -> Bool {
        let service = serviceName(for: context)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "GeminiAPIKey",
            kSecReturnData as String: false,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
