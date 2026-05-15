@testable import Normal
import Foundation

final class FakeSharedStore: SharedStoreProviding, @unchecked Sendable {
    var timedUnblocks: [TimedUnblockDTO] = []
    var schedules: [ScheduleDTO] = []

    func loadTimedUnblocks() -> [TimedUnblockDTO] { timedUnblocks }
    func saveTimedUnblocks(_ unblocks: [TimedUnblockDTO]) { timedUnblocks = unblocks }

    func upsertTimedUnblock(_ unblock: TimedUnblockDTO) {
        timedUnblocks.removeAll { $0.id == unblock.id }
        timedUnblocks.append(unblock)
    }

    func removeTimedUnblock(id: String) {
        timedUnblocks.removeAll { $0.id == id }
    }

    func findTimedUnblock(activityName: String) -> TimedUnblockDTO? {
        timedUnblocks.first { $0.activityName == activityName }
    }

    func isMainTimedUnblockActive() -> Bool {
        guard let main = timedUnblocks.first(where: { $0.id == "main" }) else { return false }
        return main.endDate > .now
    }

    func saveSchedules(_ dtos: [ScheduleDTO]) { schedules = dtos }
    func loadSchedules() -> [ScheduleDTO] { schedules }
}
