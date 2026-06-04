import Foundation
import Security

struct KeychainEmergencyUnblockLedger: EmergencyUnblockLedger {
    private let service: String
    private let account: String

    init(
        service: String = "com.normalengineering.normal.emergencyUnblock",
        account: String = "ledger"
    ) {
        self.service = service
        self.account = account
    }

    func load() -> [Date] {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let seconds = try? PropertyListDecoder().decode([Double].self, from: data)
        else { return [] }

        return seconds.map { Date(timeIntervalSinceReferenceDate: $0) }
    }

    func save(_ dates: [Date]) {
        let seconds = dates.map(\.timeIntervalSinceReferenceDate)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary // exact Double round-trip (XML would stringify reals)
        guard let data = try? encoder.encode(seconds) else { return }

        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery() as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return }

        var insert = baseQuery()
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
