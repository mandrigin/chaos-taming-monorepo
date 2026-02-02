import Foundation
import Security

/// Manages AI provider API key storage and retrieval from macOS Keychain.
///
/// Uses per-provider, per-context keychain items:
/// - `InputForge-gemini-work-apikey`
/// - `InputForge-anthropic-personal-apikey`
/// - etc.
struct KeychainService: Sendable {
    private static let servicePrefix = "InputForge"

    /// Returns the keychain service name for a given provider and context.
    static func serviceName(provider: AIBackend, context: ProjectContext) -> String {
        "\(servicePrefix)-\(provider.rawValue)-\(context.rawValue)-apikey"
    }

    // MARK: - Legacy Migration

    /// Old service names used when only Gemini was supported.
    private static func legacyServiceName(for context: ProjectContext) -> String {
        switch context {
        case .work: return "\(servicePrefix)-Work-GeminiKey"
        case .personal: return "\(servicePrefix)-Personal-GeminiKey"
        }
    }

    /// Migrates old Gemini-specific keychain entries to the new per-provider format.
    /// Called lazily on first retrieval for Gemini.
    private static func migrateGeminiKeyIfNeeded(context: ProjectContext) {
        let newService = serviceName(provider: .gemini, context: context)

        // Check if new key already exists
        let checkQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: newService,
            kSecAttrAccount as String: "APIKey",
            kSecReturnData as String: false,
        ]
        if SecItemCopyMatching(checkQuery as CFDictionary, nil) == errSecSuccess {
            return // Already migrated
        }

        // Try to read from legacy location
        let legacyService = legacyServiceName(for: context)
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: "GeminiAPIKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(legacyQuery as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return
        }

        // Store in new location
        storeAPIKey(key, provider: .gemini, context: context)
    }

    // MARK: - Primary API (per-provider, per-context)

    /// Retrieve the API key for the given provider and context.
    static func retrieveAPIKey(provider: AIBackend, context: ProjectContext) -> String? {
        if provider == .gemini {
            migrateGeminiKeyIfNeeded(context: context)
        }

        let service = serviceName(provider: provider, context: context)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "APIKey",
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

    /// Store or update the API key for the given provider and context.
    @discardableResult
    static func storeAPIKey(_ key: String, provider: AIBackend, context: ProjectContext) -> Bool {
        let service = serviceName(provider: provider, context: context)
        guard let data = key.data(using: .utf8) else { return false }

        // Delete existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "APIKey",
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new entry
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "APIKey",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete the API key for the given provider and context.
    @discardableResult
    static func deleteAPIKey(provider: AIBackend, context: ProjectContext) -> Bool {
        let service = serviceName(provider: provider, context: context)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "APIKey",
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if an API key exists for the given provider and context.
    static func hasAPIKey(provider: AIBackend, context: ProjectContext) -> Bool {
        if provider == .gemini {
            migrateGeminiKeyIfNeeded(context: context)
        }

        let service = serviceName(provider: provider, context: context)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "APIKey",
            kSecReturnData as String: false,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Convenience aliases (used by SettingsView)

    static func save(apiKey: String, provider: AIBackend, context: ProjectContext) throws {
        guard storeAPIKey(apiKey, provider: provider, context: context) else {
            throw KeychainError.saveFailed
        }
    }

    static func retrieve(provider: AIBackend, context: ProjectContext) -> String? {
        retrieveAPIKey(provider: provider, context: context)
    }

    static func delete(provider: AIBackend, context: ProjectContext) {
        deleteAPIKey(provider: provider, context: context)
    }

    enum KeychainError: LocalizedError {
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .saveFailed:
                return "Keychain save failed"
            }
        }
    }
}
