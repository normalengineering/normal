import Foundation

nonisolated protocol SharedStoreProviding: Sendable {
    func loadTimedUnblocks() -> [TimedUnblockDTO]
    func saveTimedUnblocks(_ unblocks: [TimedUnblockDTO])
    func upsertTimedUnblock(_ unblock: TimedUnblockDTO)
    func removeTimedUnblock(id: String)
    func findTimedUnblock(activityName: String) -> TimedUnblockDTO?
    func isMainTimedUnblockActive() -> Bool
    func saveSchedules(_ dtos: [ScheduleDTO])
    func loadSchedules() -> [ScheduleDTO]
}
