import Foundation

struct SharedStore: SharedStoreProviding, Sendable {
    private nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: SharedConstants.appGroupID)
            ?? UserDefaults.standard
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

    func isScheduleOverrideActive() -> Bool {
        defaults.bool(forKey: SharedConstants.DefaultsKey.scheduleOverride)
    }

    func setScheduleOverrideActive(_ active: Bool) {
        defaults.set(active, forKey: SharedConstants.DefaultsKey.scheduleOverride)
    }

    func isCustomDomainsEnabled() -> Bool {
        defaults.bool(forKey: SharedConstants.DefaultsKey.customDomainsEnabled)
    }

    func setCustomDomainsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: SharedConstants.DefaultsKey.customDomainsEnabled)
    }

    func saveUsageLimits(_ limits: [UsageLimitDTO]) {
        let data = try? PropertyListEncoder().encode(limits)
        defaults.set(data, forKey: SharedConstants.DefaultsKey.usageLimits)
    }

    func loadUsageLimits() -> [UsageLimitDTO] {
        guard let data = defaults.data(forKey: SharedConstants.DefaultsKey.usageLimits) else {
            return []
        }
        return (try? PropertyListDecoder().decode([UsageLimitDTO].self, from: data)) ?? []
    }

    func saveUsageDayState(_ state: UsageDayStateDTO) {
        let data = try? PropertyListEncoder().encode(state)
        defaults.set(data, forKey: SharedConstants.DefaultsKey.usageDayState)
    }

    func loadUsageDayState() -> UsageDayStateDTO {
        guard let data = defaults.data(forKey: SharedConstants.DefaultsKey.usageDayState) else {
            return .empty
        }
        return (try? PropertyListDecoder().decode(UsageDayStateDTO.self, from: data)) ?? .empty
    }

    func saveUsageRegistration(_ fingerprint: String?) {
        defaults.set(fingerprint, forKey: SharedConstants.DefaultsKey.usageRegistration)
    }

    func loadUsageRegistration() -> String? {
        defaults.string(forKey: SharedConstants.DefaultsKey.usageRegistration)
    }

    func saveUsageLimitsIntervalStart(_ date: Date) {
        defaults.set(date.timeIntervalSinceReferenceDate, forKey: SharedConstants.DefaultsKey.usageLimitsIntervalStart)
    }

    func loadUsageLimitsIntervalStart() -> Date? {
        let value = defaults.double(forKey: SharedConstants.DefaultsKey.usageLimitsIntervalStart)
        return value == 0 ? nil : Date(timeIntervalSinceReferenceDate: value)
    }
}
