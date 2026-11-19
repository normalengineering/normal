import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class NormalMonitor: DeviceActivityMonitor {
    private let sharedStore = SharedStore()
    private let store = ManagedSettingsStore()
    private let limitStore = ManagedSettingsStore(named: .dailyLimits)

    private static let thresholdGraceSeconds: TimeInterval = 10

    override func intervalDidStart(for activity: DeviceActivityName) {
        if activity.rawValue == SharedConstants.usageLimitsActivityName {
            sharedStore.resetUsageDayIfStale()
            sharedStore.saveUsageLimitsIntervalStart(.now)
            limitStore.syncDailyLimits(from: sharedStore)
        }
        reconcile("intervalDidStart", activity: activity.rawValue)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        reconcile("intervalDidEnd", activity: activity.rawValue)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity _: DeviceActivityName
    ) {
        if let limit = credibleUsageLimit(eventName: event.rawValue, minutes: \.minutesPerDay) {
            sharedStore.recordUsageState(.reached, for: limit.id)
            limitStore.syncDailyLimits(from: sharedStore)
            CallbackLog.record("monitor usage limit \(limit.minutesPerDay) min: reached")
        }
        reconcile("eventDidReachThreshold", activity: event.rawValue)
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity _: DeviceActivityName
    ) {
        if let limit = credibleUsageLimit(
            eventName: event.rawValue,
            minutes: { $0.minutesPerDay - SharedConstants.usageLimitWarningMinutes }
        ) {
            sharedStore.recordUsageState(.warning, for: limit.id)
            CallbackLog.record("monitor usage limit \(limit.minutesPerDay) min: warning")
        }
        reconcile("eventWillReachThresholdWarning", activity: event.rawValue)
    }

    private func reconcile(_ callback: String, activity: String) {
        let now = Date.now
        let before = store.currentShields()
        guard
            let plan = ShieldReconciler.reconcile(
                sharedStore: sharedStore,
                shields: store,
                monitoredActivities: Set(DeviceActivityCenter().activities.map(\.rawValue)),
                at: now
            )
        else { return }
        CallbackLog.record(
            "monitor \(callback) \(label(for: activity)): "
                + "[shields \(summary(before)) -> \(summary(plan))]"
        )
    }

    private func credibleUsageLimit(
        eventName: String,
        minutes: (UsageLimitDTO) -> Int
    ) -> UsageLimitDTO? {
        guard !sharedStore.isUsageDayOverridden(),
            let id = SharedConstants.usageLimitID(fromEventName: eventName),
            let limit = sharedStore.loadUsageLimits().first(where: { $0.id == id })
        else { return nil }

        if let start = sharedStore.loadUsageLimitsIntervalStart(),
            Date.now.timeIntervalSince(start) < Self.thresholdGraceSeconds
        {
            CallbackLog.record(
                "monitor usage limit \(limit.minutesPerDay) min: dropped, "
                    + "\(Date.now.timeIntervalSince(start).formatted(.number.precision(.fractionLength(1)))) s after the interval started"
            )
            return nil
        }
        guard sharedStore.usagePeriod.couldHaveMetered(minutes: minutes(limit), by: .now) else {
            CallbackLog.record("monitor usage limit \(limit.minutesPerDay) min: dropped, too soon after the reset")
            return nil
        }
        return limit
    }

    private func summary(_ plan: ShieldPlan) -> String {
        "\(plan.applications.count) apps, \(plan.categories.count) cats"
    }

    private func label(for activity: String) -> String {
        sharedStore.loadSchedules()
            .first { SharedConstants.scheduleActivityName(for: $0.id) == activity }
            .map { "\"\($0.name)\"" } ?? activity
    }
}
