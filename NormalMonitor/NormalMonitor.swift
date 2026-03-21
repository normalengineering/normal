import DeviceActivity
import Foundation
import FamilyControls
import ManagedSettings

final class NormalMonitor: DeviceActivityMonitor {
    private let sharedStore = SharedStore()
    private let mainStore = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        let name = activity.rawValue

        if name.hasPrefix("schedule_") {
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

    private func handleTimedUnblockExpired(activityName: String) {
        guard let dto = sharedStore.findTimedUnblock(activityName: activityName),
              let selection = try? FamilyActivitySelection.fromData(dto.selectionData)
        else { return }

        if dto.isGroupUnblock {
            guard !sharedStore.isMainTimedUnblockActive() else {
                sharedStore.removeTimedUnblock(id: dto.id)
                return
            }
            addToShields(selection: selection)
        } else {
            applyShieldOnAll(selection: selection)
        }

        sharedStore.removeTimedUnblock(id: dto.id)
    }

    private func handleScheduleIntervalStart(activityName: String) {
        guard let schedule = findSchedule(activityName: activityName) else { return }
        guard isActiveToday(schedule: schedule) else { return }
        guard let selection = try? FamilyActivitySelection.fromData(schedule.selectionData) else { return }

        if schedule.shouldBlock {
            addToShields(selection: selection)
        } else {
            removeFromShields(selection: selection)
        }
    }

    private func handleScheduleIntervalEnd(activityName: String) {
        guard let schedule = findSchedule(activityName: activityName) else { return }
        guard schedule.isTimed else { return }
        guard let selection = try? FamilyActivitySelection.fromData(schedule.selectionData) else { return }

        if schedule.shouldBlock {
            removeFromShields(selection: selection)
        } else {
            addToShields(selection: selection)
        }
    }

    private func applyShieldOnAll(selection: FamilyActivitySelection) {
        mainStore.shield.applications = selection.applicationTokens
        mainStore.shield.webDomains = selection.webDomainTokens
        mainStore.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    private func addToShields(selection: FamilyActivitySelection) {
        var currentApps = mainStore.shield.applications ?? Set()
        currentApps.formUnion(selection.applicationTokens)
        mainStore.shield.applications = currentApps

        var currentWeb = mainStore.shield.webDomains ?? Set()
        currentWeb.formUnion(selection.webDomainTokens)
        mainStore.shield.webDomains = currentWeb

        var currentCats = extractCategoryTokens(from: mainStore.shield.applicationCategories)
        currentCats.formUnion(selection.categoryTokens)
        mainStore.shield.applicationCategories = currentCats.isEmpty
            ? nil : .specific(currentCats)
    }

    private func removeFromShields(selection: FamilyActivitySelection) {
        var currentApps = mainStore.shield.applications ?? Set()
        currentApps.subtract(selection.applicationTokens)
        mainStore.shield.applications = currentApps

        var currentWeb = mainStore.shield.webDomains ?? Set()
        currentWeb.subtract(selection.webDomainTokens)
        mainStore.shield.webDomains = currentWeb

        var currentCats = extractCategoryTokens(from: mainStore.shield.applicationCategories)
        currentCats.subtract(selection.categoryTokens)
        mainStore.shield.applicationCategories = currentCats.isEmpty
            ? nil : .specific(currentCats)
    }

    private func findSchedule(activityName: String) -> ScheduleDTO? {
        sharedStore.loadSchedules().first { dto in
            SharedConstants.scheduleActivityName(for: dto.id) == activityName
        }
    }

    private func isActiveToday(schedule: ScheduleDTO) -> Bool {
        let today = Calendar.current.component(.weekday, from: .now)
        return schedule.weekdays.contains(today)
    }

    private func extractCategoryTokens(
        from policy: ShieldSettings.ActivityCategoryPolicy<Application>?
    ) -> Set<ActivityCategoryToken> {
        guard case let .specific(tokens, _) = policy else { return [] }
        return tokens
    }
}
