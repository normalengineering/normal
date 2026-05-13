import DeviceActivity
import FamilyControls
import Foundation
import Observation

@MainActor
@Observable
final class TimedUnblockService {
    private let activityCenter: any DeviceActivityProviding
    private let sharedStore: any SharedStoreProviding
    private let onExpiration: @MainActor @Sendable () -> Void

    private(set) var activeUnblocks: [String: Date] = [:]
    private var expirationTasks: [String: Task<Void, Never>] = [:]

    init(
        activityCenter: any DeviceActivityProviding = DeviceActivityCenter(),
        sharedStore: any SharedStoreProviding = SharedStore(),
        onExpiration: @escaping @MainActor @Sendable () -> Void = { ScreenTimeService.shared.notifyUpdate() }
    ) {
        self.activityCenter = activityCenter
        self.sharedStore = sharedStore
        self.onExpiration = onExpiration
        restoreState()
    }

    var isMainUnblockActive: Bool {
        activeUnblocks["main"] != nil
    }

    func isGroupUnblockActive(groupId: UUID) -> Bool {
        activeUnblocks[groupId.uuidString] != nil
    }

    var mainUnblockEndDate: Date? {
        activeUnblocks["main"]
    }

    func groupUnblockEndDate(groupId: UUID) -> Date? {
        activeUnblocks[groupId.uuidString]
    }

    func startMain(
        duration: UnblockDuration,
        selection: FamilyActivitySelection,
        screenTimeService: any ScreenTimeProviding,
        allowAppDelete: Bool = false
    ) throws {
        let id = "main"
        let activityName = SharedConstants.mainTimedUnblockActivityName

        cancelMonitoring(activityName: activityName)
        cancelAllGroupUnblocks()

        let endDate = Date.now.addingTimeInterval(duration.timeInterval)

        screenTimeService.removeShieldOnAll(allowAppDelete: allowAppDelete)

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
        scheduleExpiration(id: id, at: endDate)
    }

    func startGroup(
        duration: UnblockDuration,
        groupId: UUID,
        selection: FamilyActivitySelection,
        screenTimeService: any ScreenTimeProviding
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
        scheduleExpiration(id: id, at: endDate)
    }

    func cancelMain(
        selection: FamilyActivitySelection,
        screenTimeService: any ScreenTimeProviding,
        preventAppDelete: Bool = false
    ) {
        let id = "main"
        cancelMonitoring(activityName: SharedConstants.mainTimedUnblockActivityName)
        screenTimeService.applyShieldOnAll(selection: selection, preventAppDelete: preventAppDelete)
        cancelAllGroupUnblocks()
        sharedStore.removeTimedUnblock(id: id)
        cancelExpiration(id: id)
        activeUnblocks.removeValue(forKey: id)
    }

    func updateMainSelection(_ selection: FamilyActivitySelection) {
        guard isMainUnblockActive, let endDate = activeUnblocks["main"] else { return }
        guard let dto = try? TimedUnblockDTO(
            id: "main",
            selectionData: selection.toData(),
            endDate: endDate,
            activityName: SharedConstants.mainTimedUnblockActivityName,
            isGroupUnblock: false
        ) else { return }
        sharedStore.upsertTimedUnblock(dto)
    }

    func updateGroupSelection(groupId: UUID, selection: FamilyActivitySelection) {
        let id = groupId.uuidString
        guard isGroupUnblockActive(groupId: groupId), let endDate = activeUnblocks[id] else { return }
        let activityName = SharedConstants.groupTimedUnblockActivityName(for: groupId)
        guard let dto = try? TimedUnblockDTO(
            id: id,
            selectionData: selection.toData(),
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: true
        ) else { return }
        sharedStore.upsertTimedUnblock(dto)
    }

    func cancelGroup(
        groupId: UUID,
        selection: FamilyActivitySelection,
        screenTimeService: any ScreenTimeProviding
    ) {
        let id = groupId.uuidString
        let activityName = SharedConstants.groupTimedUnblockActivityName(for: groupId)
        cancelMonitoring(activityName: activityName)
        screenTimeService.addToShields(selection: selection)
        sharedStore.removeTimedUnblock(id: id)
        cancelExpiration(id: id)
        activeUnblocks.removeValue(forKey: id)
    }

    private func scheduleExpiration(id: String, at date: Date) {
        cancelExpiration(id: id)
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else {
            activeUnblocks.removeValue(forKey: id)
            return
        }
        expirationTasks[id] = Task {
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            activeUnblocks.removeValue(forKey: id)
            expirationTasks.removeValue(forKey: id)
            onExpiration()
        }
    }

    private func cancelExpiration(id: String) {
        expirationTasks[id]?.cancel()
        expirationTasks.removeValue(forKey: id)
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
            cancelExpiration(id: key)
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
                scheduleExpiration(id: unblock.id, at: unblock.endDate)
            } else {
                sharedStore.removeTimedUnblock(id: unblock.id)
            }
        }
    }
}
