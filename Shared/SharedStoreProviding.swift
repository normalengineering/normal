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
    func loadScheduleOverrideSince() -> Date?
    func isCustomDomainsEnabled() -> Bool
    func setCustomDomainsEnabled(_ enabled: Bool)
    func saveUsageLimits(_ limits: [UsageLimitDTO])
    func loadUsageLimits() -> [UsageLimitDTO]
    func saveUsageDayState(_ state: UsageDayStateDTO)
    func loadUsageDayState() -> UsageDayStateDTO
    func saveUsageRegistration(_ fingerprint: String?)
    func loadUsageRegistration() -> String?
    func saveUsageLimitsIntervalStart(_ date: Date)
    func loadUsageLimitsIntervalStart() -> Date?
    func saveUsageLimitConfig(_ config: UsageLimitConfig)
    func loadUsageLimitConfig() -> UsageLimitConfig
}

enum ScheduleStartDecision: Equatable {
    case skip
    case apply
}

extension SharedStoreProviding {
    func isUnblockAllInEffect() -> Bool {
        isMainTimedUnblockActive() || isScheduleOverrideActive()
    }

    func suppressesSchedule(windowStart: Date) -> Bool {
        if isMainTimedUnblockActive() {
            return true
        }
        guard isScheduleOverrideActive() else { return false }
        guard let since = loadScheduleOverrideSince() else { return true }
        return windowStart < since
    }

    func resolveScheduleStart(windowStart: Date) -> ScheduleStartDecision {
        if isMainTimedUnblockActive() {
            return .skip
        }
        guard isScheduleOverrideActive() else { return .apply }
        if let since = loadScheduleOverrideSince(), windowStart < since {
            return .skip
        }
        setScheduleOverrideActive(false)
        return .apply
    }

    var usagePeriod: UsagePeriod {
        loadUsageLimitConfig().period
    }

    func usageState(for id: UUID, on date: Date = .now) -> UsageLimitState {
        loadUsageDayState().state(for: id, on: date, period: usagePeriod)
    }

    func usageStates(for ids: [UUID], on date: Date = .now) -> [UUID: UsageLimitState] {
        let dayState = loadUsageDayState()
        let period = usagePeriod
        return Dictionary(
            ids.map { ($0, dayState.state(for: $0, on: date, period: period)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func recordUsageState(_ state: UsageLimitState, for id: UUID, on date: Date = .now) {
        let period = usagePeriod
        mutateUsageDayState { $0.recording(state, for: id, on: date, period: period) }
    }

    func clearUsageState(for id: UUID, on date: Date = .now) {
        let period = usagePeriod
        mutateUsageDayState { $0.clearing(id, on: date, period: period) }
    }

    func resetUsageDayIfStale(on date: Date = .now) {
        let period = usagePeriod
        guard loadUsageDayState().isStale(on: date, period: period) else { return }
        saveUsageDayState(.fresh(on: date, period: period))
    }

    func moveUsageDay(from old: UsagePeriod, to new: UsagePeriod, on date: Date = .now) {
        mutateUsageDayState { $0.moving(from: old, to: new, on: date) }
    }

    func overrideUsageDay(on date: Date = .now) {
        saveUsageDayState(loadUsageDayState().overriding(on: date, period: usagePeriod))
    }

    func isUsageDayOverridden(on date: Date = .now) -> Bool {
        let current = loadUsageDayState()
        return !current.isStale(on: date, period: usagePeriod) && current.isOverridden
    }

    func reachedUsageLimits(on date: Date = .now) -> [UsageLimitDTO] {
        guard !isUsageDayOverridden(on: date) else { return [] }
        let limits = loadUsageLimits()
        let states = usageStates(for: limits.map(\.id), on: date)
        return limits.filter { states[$0.id] == .reached }
    }

    private func mutateUsageDayState(_ transform: (UsageDayStateDTO) -> UsageDayStateDTO) {
        let current = loadUsageDayState()
        let updated = transform(current)
        guard updated != current else { return }
        saveUsageDayState(updated)
    }
}
