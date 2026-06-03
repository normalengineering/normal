import Foundation

nonisolated protocol EmergencyUnblockLedger: Sendable {
    func load() -> [Date]
    func save(_ dates: [Date])
}
