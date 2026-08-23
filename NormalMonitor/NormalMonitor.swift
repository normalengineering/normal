import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class NormalMonitor: DeviceActivityMonitor {
    private let sharedStore = SharedStore()
    private let store = ManagedSettingsStore()

    private static let thresholdGraceSeconds: TimeInterval = 10

    override func intervalDidStart(for activity: DeviceActivityName) {
        let name = activity.rawValue
        if name == SharedConstants.usageLimitsActivityName {
            sharedStore.resetUsageDayIfStale()
            sharedStore.saveUsageLimitsIntervalStart(.now)
        } else if name.hasPrefix("schedule_") {
            handleScheduleIntervalStart(activityName: name)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        let name = activity.rawValue
        if name.hasPrefix("timedUnblock_") {
            handleTimedUnblockExpired(activityName: name)
        } else if name.hasPrefix("schedule_") {
            handleScheduleIntervalEnd(activityName: name)
        }
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity _: DeviceActivityName
    ) {
        guard !sharedStore.isUsageDayOverridden(),
              let limit = findUsageLimit(eventName: event.rawValue)
        else { return }

        if let start = sharedStore.loadUsageLimitsIntervalStart(),
           Date.now.timeIntervalSince(start) < Self.thresholdGraceSeconds {
            return
        }

        sharedStore.recordUsageState(.reached, for: limit.id)
        enforce(limit)
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity _: DeviceActivityName
    ) {
        guard !sharedStore.isUsageDayOverridden(),
              let limit = findUsageLimit(eventName: event.rawValue)
        else { return }
        sharedStore.recordUsageState(.warning, for: limit.id)
    }

    /// Re-shields a limit's apps the moment its daily allowance runs out,
    /// leaving everything else exactly as it was.
    private func enforce(_ limit: UsageLimitDTO) {
        guard let selection = try? FamilyActivitySelection.fromData(limit.selectionData) else { return }
        store.unionShields(with: selection)
    }

    private func findUsageLimit(eventName: String) -> UsageLimitDTO? {
        guard let id = SharedConstants.usageLimitID(fromEventName: eventName) else { return nil }
        return sharedStore.loadUsageLimits().first { $0.id == id }
    }

    private func handleTimedUnblockExpired(activityName: String) {
        guard let dto = sharedStore.findTimedUnblock(activityName: activityName),
              let selection = try? FamilyActivitySelection.fromData(dto.selectionData)
        else { return }

        let domains = gatedDomains(dto.customDomains)
        if dto.isGroupUnblock {
            guard !sharedStore.isMainTimedUnblockActive() else {
                sharedStore.removeTimedUnblock(id: dto.id)
                return
            }
            store.unionShields(with: selection)
            store.unionFilterDomains(domains)
        } else {
            store.replaceShields(with: selection)
            store.replaceFilterDomains(domains)
            if dto.blockAllPreventsAppDelete == true {
                store.application.denyAppRemoval = true
            }
        }
        sharedStore.removeTimedUnblock(id: dto.id)
    }

    private func handleScheduleIntervalStart(activityName: String) {
        guard let schedule = findSchedule(activityName: activityName),
              schedule.startApplies(on: .now),
              let selection = try? FamilyActivitySelection.fromData(schedule.selectionData)
        else { return }

        guard sharedStore.resolveScheduleStart() == .apply else { return }

        let domains = gatedDomains(schedule.customDomains)
        if schedule.shouldBlock {
            store.unionShields(with: selection)
            store.unionFilterDomains(domains)
        } else {
            store.subtractShields(with: selection)
            store.subtractFilterDomains(domains)
            applyUsageFloor()
        }
    }

    private func handleScheduleIntervalEnd(activityName: String) {
        guard let schedule = findSchedule(activityName: activityName),
              schedule.isTimed,
              schedule.endApplies(on: .now),
              let selection = try? FamilyActivitySelection.fromData(schedule.selectionData)
        else { return }

        let domains = gatedDomains(schedule.customDomains)
        if schedule.shouldBlock {
            store.subtractShields(with: selection)
            store.subtractFilterDomains(domains)
            applyUsageFloor()
        } else {
            store.unionShields(with: selection)
            store.unionFilterDomains(domains)
        }
    }

    /// Shields never drop below the limits already spent today.
    ///
    /// Scheduled unblocks fire in this process rather than through
    /// `ScreenTimeService`, so its floor does not cover them — without this a
    /// scheduled unblock window would hand back an allowance already used up.
    private func applyUsageFloor() {
        for limit in sharedStore.reachedUsageLimits() {
            guard let selection = try? FamilyActivitySelection.fromData(limit.selectionData) else { continue }
            store.unionShields(with: selection)
        }
    }

    private func gatedDomains(_ domains: [String]) -> [String] {
        sharedStore.isCustomDomainsEnabled() ? domains : []
    }

    private func findSchedule(activityName: String) -> ScheduleDTO? {
        sharedStore.loadSchedules().first { dto in
            SharedConstants.scheduleActivityName(for: dto.id) == activityName
        }
    }
}
