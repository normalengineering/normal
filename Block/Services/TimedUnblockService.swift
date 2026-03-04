import DeviceActivity
import FamilyControls
import Foundation
import Observation

@MainActor
@Observable
final class TimedUnblockService {
    private let activityCenter: any DeviceActivityProviding
    private let sharedStore: SharedStore

    private(set) var activeUnblocks: [String: Date] = [:]

    init(
        activityCenter: any DeviceActivityProviding = DeviceActivityCenter(),
        sharedStore: SharedStore = SharedStore()
    ) {
        self.activityCenter = activityCenter
        self.sharedStore = sharedStore
        restoreState()
    }

    var isMainUnblockActive: Bool {
        isActive(id: "main")
    }

    func isGroupUnblockActive(groupId: UUID) -> Bool {
        isActive(id: groupId.uuidString)
    }

    var mainUnblockEndDate: Date? {
        endDate(for: "main")
    }

    func groupUnblockEndDate(groupId: UUID) -> Date? {
        endDate(for: groupId.uuidString)
    }

    func startMain(
        duration: UnblockDuration,
        selection: FamilyActivitySelection,
        screenTimeService: ScreenTimeService
    ) throws {
        let id = "main"
        let activityName = SharedConstants.mainTimedUnblockActivityName

        cancelMonitoring(activityName: activityName)
        cancelAllGroupUnblocks()

        let endDate = Date.now.addingTimeInterval(duration.timeInterval)

        screenTimeService.removeShieldOnAll()

        try scheduleActivity(name: activityName, endDate: endDate)

        let dto = try TimedUnblockDTO(
            id: id,
            selectionData: selection.toData(),
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: false
        )
        sharedStore.upsertTimedUnblock(dto)
        activeUnblocks[id] = endDate
    }

    func startGroup(
        duration: UnblockDuration,
        groupId: UUID,
        selection: FamilyActivitySelection,
        screenTimeService: ScreenTimeService
    ) throws {
        let id = groupId.uuidString
        let activityName = SharedConstants.groupTimedUnblockActivityName(for: groupId)

        cancelMonitoring(activityName: activityName)

        let endDate = Date.now.addingTimeInterval(duration.timeInterval)

        screenTimeService.removeFromShields(selection: selection)

        try scheduleActivity(name: activityName, endDate: endDate)

        let dto = try TimedUnblockDTO(
            id: id,
            selectionData: selection.toData(),
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: true
        )
        sharedStore.upsertTimedUnblock(dto)
        activeUnblocks[id] = endDate
    }

    func cancelMain(
        selection: FamilyActivitySelection,
        screenTimeService: ScreenTimeService
    ) {
        cancelMonitoring(activityName: SharedConstants.mainTimedUnblockActivityName)
        screenTimeService.applyShieldOnAll(selection: selection)
        cancelAllGroupUnblocks()
        sharedStore.removeTimedUnblock(id: "main")
        activeUnblocks.removeValue(forKey: "main")
    }

    func cancelGroup(
        groupId: UUID,
        selection: FamilyActivitySelection,
        screenTimeService: ScreenTimeService
    ) {
        let activityName = SharedConstants.groupTimedUnblockActivityName(for: groupId)
        cancelMonitoring(activityName: activityName)
        screenTimeService.addToShields(selection: selection)
        sharedStore.removeTimedUnblock(id: groupId.uuidString)
        activeUnblocks.removeValue(forKey: groupId.uuidString)
    }

    private func isActive(id: String) -> Bool {
        guard let date = activeUnblocks[id] else { return false }
        return date > .now
    }

    private func endDate(for id: String) -> Date? {
        guard let date = activeUnblocks[id], date > .now else { return nil }
        return date
    }

    private func cancelMonitoring(activityName: String) {
        activityCenter.stopMonitoring([DeviceActivityName(activityName)])
    }

    private func cancelAllGroupUnblocks() {
        let groupKeys = activeUnblocks.keys.filter { $0 != "main" }
        for key in groupKeys {
            if let uuid = UUID(uuidString: key) {
                let activityName = SharedConstants.groupTimedUnblockActivityName(for: uuid)
                cancelMonitoring(activityName: activityName)
            }
            sharedStore.removeTimedUnblock(id: key)
            activeUnblocks.removeValue(forKey: key)
        }
    }

    private func scheduleActivity(name: String, endDate: Date) throws {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: .now
        )
        let endComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: endDate
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        try activityCenter.startMonitoring(
            DeviceActivityName(name),
            during: schedule,
            events: [:]
        )
    }

    private func restoreState() {
        let unblocks = sharedStore.loadTimedUnblocks()
        for unblock in unblocks {
            if unblock.endDate > .now {
                activeUnblocks[unblock.id] = unblock.endDate
            } else {
                sharedStore.removeTimedUnblock(id: unblock.id)
            }
        }
    }
}
