import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class NormalMonitor: DeviceActivityMonitor {
    private let sharedStore = SharedStore()
    private let store = ManagedSettingsStore()

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
            store.unionShields(with: selection)
        } else {
            store.replaceShields(with: selection)
        }
        sharedStore.removeTimedUnblock(id: dto.id)
    }

    private func handleScheduleIntervalStart(activityName: String) {
        guard let schedule = findSchedule(activityName: activityName),
              isActiveToday(schedule: schedule),
              let selection = try? FamilyActivitySelection.fromData(schedule.selectionData)
        else { return }

        if schedule.shouldBlock {
            store.unionShields(with: selection)
        } else {
            store.subtractShields(with: selection)
        }
    }

    private func handleScheduleIntervalEnd(activityName: String) {
        guard let schedule = findSchedule(activityName: activityName),
              schedule.isTimed,
              let selection = try? FamilyActivitySelection.fromData(schedule.selectionData)
        else { return }

        if schedule.shouldBlock {
            store.subtractShields(with: selection)
        } else {
            store.unionShields(with: selection)
        }
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
}
