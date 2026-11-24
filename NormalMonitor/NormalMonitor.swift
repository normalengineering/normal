import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class NormalMonitor: DeviceActivityMonitor {
    private let sharedStore = SharedStore()
    private let store = ManagedSettingsStore()
    private let limitStore = ManagedSettingsStore(named: .dailyLimits)

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

    private func summary(_ plan: ShieldPlan) -> String {
        "\(plan.applications.count) apps, \(plan.categories.count) cats"
    }

    private func label(for activity: String) -> String {
        sharedStore.loadSchedules()
            .first { SharedConstants.scheduleActivityName(for: $0.id) == activity }
            .map { "\"\($0.name)\"" } ?? activity
    }
}
