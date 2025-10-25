import Foundation
import Security

// MARK: - Keychain Manager
final class KeychainManager: @unchecked Sendable {
    static let shared = KeychainManager()
    
    private init() {}
    
    private let serviceName = "com.depresso.auth"
    
    enum KeychainKey: String {
        case accessToken
        case refreshToken
        case userId
    }
    
    // MARK: - Save
    func save(_ value: String, for key: KeychainKey) throws {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw AuthError.keychainError("Failed to save: \(status)")
        }
    }
    
    // MARK: - Retrieve
    func retrieve(for key: KeychainKey) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw AuthError.keychainError("Failed to retrieve: \(status)")
        }
        
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw AuthError.keychainError("Invalid data format")
        }
        
        return value
    }
    
    // MARK: - Delete
    func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychainError("Failed to delete: \(status)")
        }
    }
    
    // MARK: - Clear All
    func clearAll() throws {
        for key in [KeychainKey.accessToken, .refreshToken, .userId] {
            try? delete(for: key)
        }
    }
}
