import DeviceActivity
import FamilyControls
import Foundation
import Observation

@MainActor
@Observable
final class ScheduleService {
    private let activityCenter: any DeviceActivityProviding
    private let sharedStore: any SharedStoreProviding

    init(
        activityCenter: any DeviceActivityProviding = DeviceActivityCenter(),
        sharedStore: any SharedStoreProviding = SharedStore()
    ) {
        self.activityCenter = activityCenter
        self.sharedStore = sharedStore
    }

    func sync(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) throws {
        let activityName = activityName(for: schedule)
        activityCenter.stopMonitoring([activityName])

        guard schedule.isEnabled else {
            applyOppositeOfScheduleAction(schedule, screenTimeService: screenTimeService)
            return
        }

        let deviceSchedule = makeDeviceSchedule(for: schedule)
        try activityCenter.startMonitoring(activityName, during: deviceSchedule, events: [:])
    }

    func remove(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) {
        activityCenter.stopMonitoring([activityName(for: schedule)])
        applyOppositeOfScheduleAction(schedule, screenTimeService: screenTimeService)
    }

    func toggleEnabled(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) throws {
        schedule.isEnabled.toggle()
        try sync(schedule, screenTimeService: screenTimeService)
    }

    func syncAllToSharedStore(_ schedules: [BlockSchedule]) {
        sharedStore.saveSchedules(schedules.compactMap { $0.toDTO() })
    }

    func syncAndPersist(
        _ schedule: BlockSchedule,
        allSchedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding
    ) throws {
        try sync(schedule, screenTimeService: screenTimeService)
        syncAllToSharedStore(allSchedules)
    }

    private func activityName(for schedule: BlockSchedule) -> DeviceActivityName {
        DeviceActivityName(SharedConstants.scheduleActivityName(for: schedule.id))
    }

    private func applyOppositeOfScheduleAction(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) {
        if schedule.shouldBlock {
            screenTimeService.removeFromShields(selection: schedule.selection)
        } else {
            screenTimeService.addToShields(selection: schedule.selection)
        }
    }

    private func makeDeviceSchedule(for schedule: BlockSchedule) -> DeviceActivitySchedule {
        var start = DateComponents()
        start.hour = schedule.startHour
        start.minute = schedule.startMinute
        start.second = 0

        let endMinutes = schedule.startHour * 60 + schedule.startMinute + schedule.durationMinutes
        var end = DateComponents()
        end.hour = (endMinutes / 60) % 24
        end.minute = endMinutes % 60
        end.second = 0

        return DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
    }
}
