import Foundation
import Security

public enum DeepSeekKeychain {
    private static let service = "com.merci.sipfolio.deepseek"
    private static let account = "api-key"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    public static func load() throws -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw DeepSeekError.keychain(status)
        }
        return key
    }

    public static func save(_ key: String) throws {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 16, !clean.contains(where: \.isWhitespace) else { throw DeepSeekError.invalidKey }
        let attributes: [String: Any] = [kSecValueData as String: Data(clean.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(clean.utf8)
            item[kSecAttrLabel as String] = "Sipfolio DeepSeek API"
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw DeepSeekError.keychain(status) }
    }

    public static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw DeepSeekError.keychain(status) }
    }
}
