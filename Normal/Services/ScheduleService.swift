import DeviceActivity
import FamilyControls
import Foundation
import Observation

@MainActor
@Observable
final class ScheduleService {
    private let activityCenter: any DeviceActivityProviding
    private let sharedStore: any SharedStoreProviding
    private let clock: () -> Date

    init(
        activityCenter: any DeviceActivityProviding = DeviceActivityCenter(),
        sharedStore: any SharedStoreProviding = SharedStore(),
        clock: @escaping () -> Date = { .now }
    ) {
        self.activityCenter = activityCenter
        self.sharedStore = sharedStore
        self.clock = clock
    }

    func sync(_ schedule: BlockSchedule) throws {
        let activityName = activityName(for: schedule)
        activityCenter.stopMonitoring([activityName])

        guard schedule.isEnabled else {
            CallbackLog.record("app sync \"\(schedule.name)\": stopped (disabled)")
            return
        }

        let deviceSchedule = makeDeviceSchedule(for: schedule)
        do {
            try activityCenter.startMonitoring(activityName, during: deviceSchedule, events: [:])
        } catch DeviceActivityCenter.MonitoringError.excessiveActivities {
            CallbackLog.record("app sync \"\(schedule.name)\": too many activities")
            throw ScheduleRegistrationError.tooManyActivities
        } catch {
            CallbackLog.record("app sync \"\(schedule.name)\": startMonitoring failed: \(error)")
            throw error
        }
        CallbackLog.record("app sync \"\(schedule.name)\": stopped + restarted")
    }

    func registerAll(
        _ schedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding
    ) {
        syncAllToSharedStore(schedules)
        let wanted = Set(schedules.filter(\.isEnabled).map { activityName(for: $0).rawValue })
        let stale = activityCenter.monitoredActivityNames.filter { $0.hasPrefix("schedule_") && !wanted.contains($0) }
        if !stale.isEmpty {
            activityCenter.stopMonitoring(stale.map { DeviceActivityName($0) })
        }
        activityCenter.syncHeartbeat(sharedStore: sharedStore, at: clock())
        for schedule in schedules where schedule.isEnabled && !isRegistered(schedule) {
            try? sync(schedule)
        }
        screenTimeService.reconcile()
    }

    private func isRegistered(_ schedule: BlockSchedule) -> Bool {
        activityCenter.registeredSchedule(for: activityName(for: schedule))?
            .hasSameWindow(as: makeDeviceSchedule(for: schedule)) == true
    }

    func mirrorCustomDomainsEnabled(_ enabled: Bool) {
        sharedStore.setCustomDomainsEnabled(enabled)
    }

    func remove(
        _ schedule: BlockSchedule,
        remaining: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding
    ) {
        activityCenter.stopMonitoring([activityName(for: schedule)])
        syncAllToSharedStore(remaining)
        activityCenter.syncHeartbeat(sharedStore: sharedStore, at: clock())
        screenTimeService.reconcile()
    }

    func toggleEnabled(
        _ schedule: BlockSchedule,
        allSchedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding
    ) throws {
        schedule.isEnabled.toggle()
        try syncAndPersist(schedule, allSchedules: allSchedules, screenTimeService: screenTimeService)
    }

    func disableAll(
        _ schedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding
    ) {
        for schedule in schedules where schedule.isEnabled {
            schedule.isEnabled = false
        }
        for schedule in schedules {
            try? sync(schedule)
        }
        syncAllToSharedStore(schedules)
        activityCenter.syncHeartbeat(sharedStore: sharedStore, at: clock())
        screenTimeService.reconcile()
    }

    func syncAllToSharedStore(_ schedules: [BlockSchedule], activating activatedID: UUID? = nil) {
        var previous: [UUID: Date] = [:]
        for dto in sharedStore.loadSchedules() {
            previous[dto.id] = dto.activatedAt
        }
        sharedStore.saveSchedules(schedules.compactMap { schedule in
            schedule.toDTO(activatedAt: schedule.id == activatedID ? clock() : previous[schedule.id])
        })
    }

    func syncAndPersist(
        _ schedule: BlockSchedule,
        allSchedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding
    ) throws {
        let previous = sharedStore.loadSchedules().first { $0.id == schedule.id }
        let wasEnabled = previous?.isEffectivelyEnabled(monitoredActivities: activityCenter.monitoredActivityNames) == true
        let rulesChanged = previous.map { !schedule.hasSameRules(as: $0) } ?? true
        let activates = schedule.isEnabled && (!wasEnabled || (schedule.isTimed && rulesChanged))
        syncAllToSharedStore(allSchedules, activating: activates ? schedule.id : nil)
        screenTimeService.reconcile()
        activityCenter.syncHeartbeat(sharedStore: sharedStore, at: clock())
        try sync(schedule)
    }

    private func activityName(for schedule: BlockSchedule) -> DeviceActivityName {
        DeviceActivityName(SharedConstants.scheduleActivityName(for: schedule.id))
    }

    private func makeDeviceSchedule(for schedule: BlockSchedule) -> DeviceActivitySchedule {
        var start = DateComponents()
        start.hour = schedule.startHour
        start.minute = schedule.startMinute
        start.second = 0

        let startSeconds = (schedule.startHour * 60 + schedule.startMinute) * 60
        let durationSeconds = min(schedule.effectiveDurationMinutes * 60, 86400 - 1)
        let endSeconds = (startSeconds + durationSeconds) % 86400
        var end = DateComponents()
        end.hour = endSeconds / 3600
        end.minute = endSeconds % 3600 / 60
        end.second = endSeconds % 60

        return DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
    }
}

enum ScheduleRegistrationError: LocalizedError {
    case tooManyActivities

    var errorDescription: String? {
        String(localized: "Saved, but iOS only tracks 20 schedules and timers at once, so this schedule may start or end up to 30 minutes late. Turn off another schedule to make it exact.")
    }
}
