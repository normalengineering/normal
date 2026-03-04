import Foundation

struct SharedStore: Sendable {
    private let defaults: UserDefaults

    init() {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            fatalError(
                "App Group '\(SharedConstants.appGroupID)' not configured. "
                    + "Add the App Groups capability to both targets in Xcode."
            )
        }
        self.defaults = defaults
    }

    func loadTimedUnblocks() -> [TimedUnblockDTO] {
        guard let data = defaults.data(forKey: SharedConstants.DefaultsKey.timedUnblocks) else {
            return []
        }
        return (try? PropertyListDecoder().decode([TimedUnblockDTO].self, from: data)) ?? []
    }

    func saveTimedUnblocks(_ unblocks: [TimedUnblockDTO]) {
        let data = try? PropertyListEncoder().encode(unblocks)
        defaults.set(data, forKey: SharedConstants.DefaultsKey.timedUnblocks)
    }

    func upsertTimedUnblock(_ unblock: TimedUnblockDTO) {
        var current = loadTimedUnblocks()
        current.removeAll { $0.id == unblock.id }
        current.append(unblock)
        saveTimedUnblocks(current)
    }

    func removeTimedUnblock(id: String) {
        var current = loadTimedUnblocks()
        current.removeAll { $0.id == id }
        saveTimedUnblocks(current)
    }

    func findTimedUnblock(activityName: String) -> TimedUnblockDTO? {
        loadTimedUnblocks().first { $0.activityName == activityName }
    }

    func isMainTimedUnblockActive() -> Bool {
        guard let main = loadTimedUnblocks().first(where: { $0.id == "main" }) else {
            return false
        }
        return main.endDate > Date.now
    }

    func saveSchedules(_ dtos: [ScheduleDTO]) {
        let data = try? PropertyListEncoder().encode(dtos)
        defaults.set(data, forKey: SharedConstants.DefaultsKey.schedules)
    }

    func loadSchedules() -> [ScheduleDTO] {
        guard let data = defaults.data(forKey: SharedConstants.DefaultsKey.schedules) else {
            return []
        }
        return (try? PropertyListDecoder().decode([ScheduleDTO].self, from: data)) ?? []
    }
}
