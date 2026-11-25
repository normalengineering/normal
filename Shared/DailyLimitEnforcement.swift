import FamilyControls
import Foundation
import ManagedSettings
import OSLog

private nonisolated let dailyLimitLogger = Logger(
    subsystem: "com.normalengineering.normal",
    category: "UsageLimits"
)

private nonisolated let monitoringStartGrace: TimeInterval = 10

extension ManagedSettingsStore.Name {
    static let dailyLimits = Self("normal.dailyLimits")
}

extension ManagedSettingsStore {
    func applyDailyLimits(_ reached: [UsageLimitDTO]) {
        let selections = reached.compactMap { try? FamilyActivitySelection.fromData($0.selectionData) }
        guard !selections.isEmpty else {
            clearAllSettings()
            return
        }

        replaceShields(with: selections.reduce(FamilyActivitySelection()) { $0.union($1) })
        application.denyAppRemoval = nil
    }

    func syncDailyLimits(from sharedStore: some SharedStoreProviding, on date: Date = .now) {
        applyDailyLimits(sharedStore.reachedUsageLimits(on: date))
    }
}

extension SharedStoreProviding {
    func enforceUsageThreshold(
        eventName: String,
        on date: Date = .now,
        apply: ([UsageLimitDTO]) -> Void
    ) {
        guard let limit = recordUsageCallback(.reached, eventName: eventName, on: date) else { return }
        apply(reachedUsageLimits(on: date))
        dailyLimitLogger.notice("Daily limit reached and shielded (\(limit.minutesPerDay, privacy: .public) min)")
        CallbackLog.record("monitor usage limit \(limit.minutesPerDay) min: reached")
    }

    func recordUsageCallback(
        _ state: UsageLimitState,
        eventName: String,
        on date: Date = .now
    ) -> UsageLimitDTO? {
        guard let id = SharedConstants.usageLimitID(fromEventName: eventName) else { return nil }
        guard !isUsageDayOverridden(on: date) else {
            dailyLimitLogger.info("Dropped \(state.rawValue, privacy: .public) callback: emergency override")
            return nil
        }
        guard let limit = loadUsageLimits().first(where: { $0.id == id }) else {
            dailyLimitLogger.info("Dropped \(state.rawValue, privacy: .public) callback: unknown limit")
            return nil
        }

        let minutes: Int
        switch state {
        case .warning: minutes = limit.minutesPerDay - SharedConstants.usageLimitWarningMinutes
        case .reached: minutes = limit.minutesPerDay
        case .under: return nil
        }

        let period = usagePeriod
        let countsPastActivity = period.countsPastActivity(createdAt: limit.createdAt, on: date)
        if !countsPastActivity,
            let createdAt = limit.createdAt,
            date.timeIntervalSince(createdAt) + 60 < TimeInterval(minutes) * 60
        {
            dailyLimitLogger.notice(
                "Dropped \(state.rawValue, privacy: .public) callback (\(limit.minutesPerDay, privacy: .public) min): too soon after creation"
            )
            CallbackLog.record("monitor usage limit \(limit.minutesPerDay) min: dropped, too soon after creation")
            return nil
        }
        if let start = loadUsageLimitsIntervalStart(),
            date.timeIntervalSince(start) < monitoringStartGrace,
            !(countsPastActivity && intervalStartFollowsRegistration(start, in: period))
        {
            dailyLimitLogger.notice(
                "Dropped \(state.rawValue, privacy: .public) callback (\(limit.minutesPerDay, privacy: .public) min): too soon after monitoring started"
            )
            CallbackLog.record("monitor usage limit \(limit.minutesPerDay) min: dropped, too soon after monitoring started")
            return nil
        }

        guard period.couldHaveMetered(minutes: minutes, by: date) else {
            dailyLimitLogger.notice(
                "Dropped \(state.rawValue, privacy: .public) callback (\(limit.minutesPerDay, privacy: .public) min): too soon after reset"
            )
            CallbackLog.record("monitor usage limit \(limit.minutesPerDay) min: dropped, too soon after the reset")
            return nil
        }

        recordUsageState(state, for: limit.id, on: date)
        return limit
    }

    private func intervalStartFollowsRegistration(_ start: Date, in period: UsagePeriod) -> Bool {
        guard start.timeIntervalSince(period.start(containing: start)) >= monitoringStartGrace,
            let registered = loadUsageLimitsRegisteredAt()
        else { return false }
        let delay = start.timeIntervalSince(registered)
        return delay >= -1 && delay < 5
    }
}
