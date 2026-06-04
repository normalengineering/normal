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
    func isScheduleOverrideActive() -> Bool
    func setScheduleOverrideActive(_ active: Bool)
}

enum ScheduleStartDecision: Equatable {
    case skip
    case apply
}

extension SharedStoreProviding {
    func isUnblockAllInEffect() -> Bool {
        isMainTimedUnblockActive() || isScheduleOverrideActive()
    }

    func resolveScheduleStart() -> ScheduleStartDecision {
        if isMainTimedUnblockActive() { return .skip }
        if isScheduleOverrideActive() { setScheduleOverrideActive(false) }
        return .apply
    }
}
