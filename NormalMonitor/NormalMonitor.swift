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
        let name = activity.rawValue
        if name == SharedConstants.usageLimitsActivityName {
            sharedStore.resetUsageDayIfStale()
            sharedStore.saveUsageLimitsIntervalStart(.now)
            limitStore.syncDailyLimits(from: sharedStore)
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
        guard let limit = credibleUsageLimit(eventName: event.rawValue, minutes: \.minutesPerDay) else { return }
        sharedStore.recordUsageState(.reached, for: limit.id)
        limitStore.syncDailyLimits(from: sharedStore)
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity _: DeviceActivityName
    ) {
        guard let limit = credibleUsageLimit(
            eventName: event.rawValue,
            minutes: { $0.minutesPerDay - SharedConstants.usageLimitWarningMinutes }
        ) else { return }
        sharedStore.recordUsageState(.warning, for: limit.id)
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
           Date.now.timeIntervalSince(start) < Self.thresholdGraceSeconds {
            return nil
        }
        guard sharedStore.usagePeriod.couldHaveMetered(minutes: minutes(limit), by: .now) else { return nil }
        return limit
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
        } else {
            store.unionShields(with: selection)
            store.unionFilterDomains(domains)
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
