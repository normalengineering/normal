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
        let activityName = DeviceActivityName(
            SharedConstants.scheduleActivityName(for: schedule.id)
        )

        activityCenter.stopMonitoring([activityName])

        guard schedule.isEnabled else {
            if schedule.shouldBlock {
                screenTimeService.removeFromShields(selection: schedule.selection)
            } else {
                screenTimeService.addToShields(selection: schedule.selection)
            }
            return
        }

        var start = DateComponents()
        start.hour = schedule.startHour
        start.minute = schedule.startMinute
        start.second = 0

        let endTotalMinutes = schedule.startHour * 60
            + schedule.startMinute
            + schedule.durationMinutes

        var end = DateComponents()
        end.hour = (endTotalMinutes / 60) % 24
        end.minute = endTotalMinutes % 60
        end.second = 0

        let deviceSchedule = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: end,
            repeats: true
        )

        try activityCenter.startMonitoring(activityName, during: deviceSchedule, events: [:])
    }

    func remove(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) {
        let activityName = DeviceActivityName(
            SharedConstants.scheduleActivityName(for: schedule.id)
        )
        activityCenter.stopMonitoring([activityName])

        if schedule.shouldBlock {
            screenTimeService.removeFromShields(selection: schedule.selection)
        } else {
            screenTimeService.addToShields(selection: schedule.selection)
        }
    }

    func toggleEnabled(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) throws {
        schedule.isEnabled.toggle()
        try sync(schedule, screenTimeService: screenTimeService)
    }

    func syncAllToSharedStore(_ schedules: [BlockSchedule]) {
        let dtos = schedules.compactMap { $0.toDTO() }
        sharedStore.saveSchedules(dtos)
    }

    func syncAndPersist(
        _ schedule: BlockSchedule,
        allSchedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding
    ) throws {
        try sync(schedule, screenTimeService: screenTimeService)
        syncAllToSharedStore(allSchedules)
    }
}
