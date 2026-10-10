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
            liftBlockIfNeeded(schedule, screenTimeService: screenTimeService)
            return
        }

        let deviceSchedule = makeDeviceSchedule(for: schedule)
        try activityCenter.startMonitoring(activityName, during: deviceSchedule, events: [:])
        applyIfActiveNow(schedule, screenTimeService: screenTimeService)
    }

    func registerAll(
        _ schedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding
    ) {
        syncAllToSharedStore(schedules)
        for schedule in schedules where schedule.isEnabled {
            try? sync(schedule, screenTimeService: screenTimeService)
        }
    }

    func mirrorCustomDomainsEnabled(_ enabled: Bool) {
        sharedStore.setCustomDomainsEnabled(enabled)
    }

    func remove(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) {
        activityCenter.stopMonitoring([activityName(for: schedule)])
        liftBlockIfNeeded(schedule, screenTimeService: screenTimeService)
    }

    func toggleEnabled(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) throws {
        schedule.isEnabled.toggle()
        try sync(schedule, screenTimeService: screenTimeService)
    }

    func setScheduleOverride(_ active: Bool) {
        sharedStore.setScheduleOverrideActive(active)
    }

    func disableAll(
        _ schedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding
    ) {
        for schedule in schedules where schedule.isEnabled {
            schedule.isEnabled = false
        }
        for schedule in schedules {
            try? sync(schedule, screenTimeService: screenTimeService)
        }
        syncAllToSharedStore(schedules)
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

    private func applyIfActiveNow(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) {
        guard let windowStart = schedule.activeWindowStart(at: .now) else { return }
        let domains = effectiveDomains(schedule)
        if schedule.shouldBlock {
            guard !sharedStore.suppressesSchedule(windowStart: windowStart) else { return }
            screenTimeService.addToShields(selection: schedule.selection, customDomains: domains)
        } else {
            screenTimeService.removeFromShields(selection: schedule.selection, customDomains: domains)
        }
    }

    private func liftBlockIfNeeded(
        _ schedule: BlockSchedule,
        screenTimeService: any ScreenTimeProviding
    ) {
        guard schedule.shouldBlock else { return }
        screenTimeService.removeFromShields(selection: schedule.selection, customDomains: effectiveDomains(schedule))
    }

    private func effectiveDomains(_ schedule: BlockSchedule) -> [String] {
        sharedStore.isCustomDomainsEnabled() ? schedule.customDomains : []
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
