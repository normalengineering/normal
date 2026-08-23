import Foundation
import Security

/// A single generic-password slot in the Keychain.
///
/// Used for counters that must survive a delete-and-reinstall — the whole point
/// of storing them outside the app container.
struct KeychainItem: Sendable {
    let service: String
    let account: String

    func loadData() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    func saveData(_ data: Data) {
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery() as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return }

        var insert = baseQuery()
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

extension KeychainItem {
    func load<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = loadData() else { return nil }
        return try? PropertyListDecoder().decode(type, from: data)
    }

    func save(_ value: some Encodable) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(value) else { return }
        saveData(data)
    }
}
