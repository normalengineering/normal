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

    func loadScheduleOverrideSince() -> Date? {
        guard let value = defaults.object(forKey: SharedConstants.DefaultsKey.scheduleOverrideSince) as? Double
        else { return nil }
        return Date(timeIntervalSinceReferenceDate: value)
    }

    func isCustomDomainsEnabled() -> Bool {
        defaults.bool(forKey: SharedConstants.DefaultsKey.customDomainsEnabled)
    }

    func setCustomDomainsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: SharedConstants.DefaultsKey.customDomainsEnabled)
    }

    func isAdultContentEnabled() -> Bool {
        defaults.bool(forKey: SharedConstants.DefaultsKey.adultContentEnabled)
    }

    func setAdultContentEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: SharedConstants.DefaultsKey.adultContentEnabled)
    }

    func isHideBlockedAppsEnabled() -> Bool {
        defaults.bool(forKey: SharedConstants.DefaultsKey.hideBlockedAppsEnabled)
    }

    func setHideBlockedAppsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: SharedConstants.DefaultsKey.hideBlockedAppsEnabled)
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

    func saveUsageLimitConfig(_ config: UsageLimitConfig) {
        let data = try? PropertyListEncoder().encode(config)
        defaults.set(data, forKey: SharedConstants.DefaultsKey.usageLimitConfig)
    }

    func saveManualBlockState(_ state: ManualBlockState) {
        let data = try? PropertyListEncoder().encode(state)
        defaults.set(data, forKey: SharedConstants.DefaultsKey.manualBlockState)
    }

    func loadManualBlockState() -> ManualBlockState? {
        guard let data = defaults.data(forKey: SharedConstants.DefaultsKey.manualBlockState) else { return nil }
        return try? PropertyListDecoder().decode(ManualBlockState.self, from: data)
    }

    func loadUsageLimitConfig() -> UsageLimitConfig {
        guard let data = defaults.data(forKey: SharedConstants.DefaultsKey.usageLimitConfig) else {
            return UsageLimitConfig()
        }
        return (try? PropertyListDecoder().decode(UsageLimitConfig.self, from: data)) ?? UsageLimitConfig()
    }
}
