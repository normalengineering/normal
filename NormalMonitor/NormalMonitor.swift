import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import os

final class NormalMonitor: DeviceActivityMonitor {
    private let sharedStore = SharedStore()
    private let store = ManagedSettingsStore()
    private let limitStore = ManagedSettingsStore(named: .dailyLimits)

    private static let dailyLimitRepairs = OSAllocatedUnfairLock(initialState: 0)

    override func intervalDidStart(for activity: DeviceActivityName) {
        if activity.rawValue == SharedConstants.usageLimitsActivityName {
            sharedStore.resetUsageDayIfStale()
            sharedStore.saveUsageLimitsIntervalStart(.now)
            limitStore.syncDailyLimits(from: sharedStore)
        }
        let center = DeviceActivityCenter()
        repairDailyLimits(after: activity, center: center)
        reconcile("intervalDidStart", activity: activity.rawValue, center: center)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        let center = DeviceActivityCenter()
        repairDailyLimits(after: activity, center: center)
        reconcile("intervalDidEnd", activity: activity.rawValue, center: center)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity _: DeviceActivityName
    ) {
        sharedStore.enforceUsageThreshold(eventName: event.rawValue, apply: limitStore.applyDailyLimits)
        reconcile("eventDidReachThreshold", activity: event.rawValue)
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity _: DeviceActivityName
    ) {
        if let limit = sharedStore.recordUsageCallback(.warning, eventName: event.rawValue) {
            CallbackLog.record("monitor usage limit \(limit.minutesPerDay) min: warning")
        }
        reconcile("eventWillReachThresholdWarning", activity: event.rawValue)
    }

    private func repairDailyLimits(after activity: DeviceActivityName, center: DeviceActivityCenter) {
        guard activity.rawValue == SharedConstants.reblockHeartbeatActivityName else { return }
        Self.dailyLimitRepairs.withLock { $0 += 1 }
        defer { Self.dailyLimitRepairs.withLock { $0 -= 1 } }
        DailyLimitMonitoring.repairOnHeartbeat(activity, center: center, store: sharedStore)
    }

    private func reconcile(
        _ callback: String,
        activity: String,
        center: DeviceActivityCenter = DeviceActivityCenter()
    ) {
        guard Self.dailyLimitRepairs.withLock({ $0 }) == 0 else {
            CallbackLog.record("monitor \(callback) \(label(for: activity)): skipped while daily limits are re-registered")
            return
        }
        let now = Date.now
        let before = store.currentShields()
        guard
            let plan = ShieldReconciler.reconcile(
                sharedStore: sharedStore,
                shields: store,
                monitoredActivities: Set(center.activities.map(\.rawValue)),
                at: now
            )
        else { return }
        CallbackLog.record(
            "monitor \(callback) \(label(for: activity)): "
                + "[shields \(summary(before)) -> \(summary(plan))]"
        )
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
