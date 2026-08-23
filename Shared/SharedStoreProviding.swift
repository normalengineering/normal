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

    // MARK: - Usage limits
    //
    // Thin load/mutate/save wrappers; the rules live on `UsageDayStateDTO`.

    func usageState(for id: UUID, on date: Date = .now) -> UsageLimitState {
        loadUsageDayState().state(for: id, on: date)
    }

    func recordUsageState(_ state: UsageLimitState, for id: UUID, on date: Date = .now) {
        mutateUsageDayState { $0.recording(state, for: id, on: date) }
    }

    func clearUsageState(for id: UUID, on date: Date = .now) {
        mutateUsageDayState { $0.clearing(id, on: date) }
    }

    /// Rolls the day over only when the previous record has actually expired.
    ///
    /// `intervalDidStart` fires both at real midnight *and* whenever the app
    /// re-registers the activity mid-day, so an unconditional reset here would
    /// hand back an allowance that has already been spent.
    func resetUsageDayIfStale(on date: Date = .now) {
        guard loadUsageDayState().isStale(on: date) else { return }
        saveUsageDayState(.fresh(on: date))
    }

    /// Marks today as outranked by an emergency unblock. Limits stop being
    /// enforced — and stop being re-armed — until the day rolls over.
    func overrideUsageDay(on date: Date = .now) {
        saveUsageDayState(loadUsageDayState().overriding(on: date))
    }

    func isUsageDayOverridden(on date: Date = .now) -> Bool {
        let current = loadUsageDayState()
        return !current.isStale(on: date) && current.isOverridden
    }

    /// Usage limits that have run out today and must stay shielded.
    func reachedUsageLimits(on date: Date = .now) -> [UsageLimitDTO] {
        let dayState = loadUsageDayState()
        guard !dayState.isOverridden else { return [] }
        return loadUsageLimits().filter { dayState.state(for: $0.id, on: date) == .reached }
    }

    /// Re-read immediately before writing. Does not make the cross-process
    /// update atomic, but narrows the window in which the app and the monitor
    /// extension can clobber each other's state.
    private func mutateUsageDayState(_ transform: (UsageDayStateDTO) -> UsageDayStateDTO) {
        let updated = transform(loadUsageDayState())
        guard updated != loadUsageDayState() else { return }
        saveUsageDayState(updated)
    }
}
