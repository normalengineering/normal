import Foundation

struct KeychainEmergencyUnblockLedger: EmergencyUnblockLedger {
    private let item: KeychainItem

    init(
        service: String = "com.normalengineering.normal.emergencyUnblock",
        account: String = "ledger"
    ) {
        item = KeychainItem(service: service, account: account)
    }

    func load() -> [Date] {
        guard let seconds = item.load([Double].self) else { return [] }
        return seconds.map { Date(timeIntervalSinceReferenceDate: $0) }
    }

    func save(_ dates: [Date]) {
        item.save(dates.map(\.timeIntervalSinceReferenceDate))
    }
}
