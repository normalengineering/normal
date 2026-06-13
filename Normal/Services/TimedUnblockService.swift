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

    static let mainID = "main"

    init(
        activityCenter: any DeviceActivityProviding = DeviceActivityCenter(),
        sharedStore: any SharedStoreProviding = SharedStore(),
        onExpiration: @escaping @MainActor @Sendable () -> Void
    ) {
        self.activityCenter = activityCenter
        self.sharedStore = sharedStore
        self.onExpiration = onExpiration
        restoreState()
    }

    var isMainUnblockActive: Bool {
        activeUnblocks[Self.mainID] != nil
    }

    var mainUnblockEndDate: Date? {
        activeUnblocks[Self.mainID]
    }

    func isGroupUnblockActive(groupId: UUID) -> Bool {
        activeUnblocks[groupId.uuidString] != nil
    }

    func groupUnblockEndDate(groupId: UUID) -> Date? {
        activeUnblocks[groupId.uuidString]
    }

    func startMain(
        duration: UnblockDuration,
        selection: FamilyActivitySelection,
        screenTimeService: any ScreenTimeProviding,
        blockAllPreventsAppDelete: Bool = false
    ) throws {
        let activityName = SharedConstants.mainTimedUnblockActivityName
        cancelMonitoring(activityName: activityName)
        cancelAllGroupUnblocks()

        let start = Date.now
        let endDate = start.addingTimeInterval(duration.timeInterval)
        screenTimeService.removeShieldOnAll(blockAllPreventsAppDelete: blockAllPreventsAppDelete)
        sharedStore.setScheduleOverrideActive(false)
        try scheduleActivity(name: activityName, start: start, endDate: endDate)

        try persist(
            id: Self.mainID,
            selection: selection,
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: false,
            blockAllPreventsAppDelete: blockAllPreventsAppDelete
        )
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

        let start = Date.now
        let endDate = start.addingTimeInterval(duration.timeInterval)
        screenTimeService.removeFromShields(selection: selection)
        try scheduleActivity(name: activityName, start: start, endDate: endDate)

        try persist(
            id: id,
            selection: selection,
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: true
        )
    }

    func cancelMain(
        selection: FamilyActivitySelection,
        screenTimeService: any ScreenTimeProviding,
        blockAllPreventsAppDelete: Bool = false
    ) {
        cancelMonitoring(activityName: SharedConstants.mainTimedUnblockActivityName)
        screenTimeService.applyShieldOnAll(
            selection: selection,
            blockAllPreventsAppDelete: blockAllPreventsAppDelete
        )
        cancelAllGroupUnblocks()
        forget(id: Self.mainID)
    }

    func cancelGroup(
        groupId: UUID,
        selection: FamilyActivitySelection,
        screenTimeService: any ScreenTimeProviding
    ) {
        let id = groupId.uuidString
        cancelMonitoring(activityName: SharedConstants.groupTimedUnblockActivityName(for: groupId))
        screenTimeService.addToShields(selection: selection)
        forget(id: id)
    }

    func clearAll() {
        for key in Array(activeUnblocks.keys) {
            if key == Self.mainID {
                cancelMonitoring(activityName: SharedConstants.mainTimedUnblockActivityName)
            } else if let uuid = UUID(uuidString: key) {
                cancelMonitoring(activityName: SharedConstants.groupTimedUnblockActivityName(for: uuid))
            }
            forget(id: key)
        }
    }

    func updateMainSelection(_ selection: FamilyActivitySelection) {
        guard let endDate = activeUnblocks[Self.mainID] else { return }
        let activityName = SharedConstants.mainTimedUnblockActivityName
        let preventAppDelete = sharedStore
            .findTimedUnblock(activityName: activityName)?.blockAllPreventsAppDelete
        try? persist(
            id: Self.mainID,
            selection: selection,
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: false,
            scheduleTask: false,
            blockAllPreventsAppDelete: preventAppDelete
        )
    }

    func updateGroupSelection(groupId: UUID, selection: FamilyActivitySelection) {
        let id = groupId.uuidString
        guard let endDate = activeUnblocks[id] else { return }
        try? persist(
            id: id,
            selection: selection,
            endDate: endDate,
            activityName: SharedConstants.groupTimedUnblockActivityName(for: groupId),
            isGroupUnblock: true,
            scheduleTask: false
        )
    }

    private func persist(
        id: String,
        selection: FamilyActivitySelection,
        endDate: Date,
        activityName: String,
        isGroupUnblock: Bool,
        scheduleTask: Bool = true,
        blockAllPreventsAppDelete: Bool? = nil
    ) throws {
        let dto = try TimedUnblockDTO(
            id: id,
            selectionData: selection.toData(),
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: isGroupUnblock,
            blockAllPreventsAppDelete: blockAllPreventsAppDelete
        )
        sharedStore.upsertTimedUnblock(dto)

        if scheduleTask {
            activeUnblocks[id] = endDate
            scheduleExpiration(id: id, at: endDate)
        }
    }

    private func forget(id: String) {
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
        let groupKeys = activeUnblocks.keys.filter { $0 != Self.mainID }
        for key in groupKeys {
            if let uuid = UUID(uuidString: key) {
                cancelMonitoring(activityName: SharedConstants.groupTimedUnblockActivityName(for: uuid))
            }
            forget(id: key)
        }
    }

    private func scheduleActivity(name: String, start: Date, endDate: Date) throws {
        let schedule = DeviceActivityScheduleFactory.window(from: start, to: endDate)
        try activityCenter.startMonitoring(
            DeviceActivityName(name),
            during: schedule,
            events: [:]
        )
    }

    func refresh(screenTimeService: any ScreenTimeProviding) {
        for (_, task) in expirationTasks {
            task.cancel()
        }
        expirationTasks.removeAll()
        activeUnblocks.removeAll()
        reconcile(screenTimeService: screenTimeService)
    }

    private func restoreState() {
        for unblock in sharedStore.loadTimedUnblocks() where unblock.endDate > .now {
            activeUnblocks[unblock.id] = unblock.endDate
            scheduleExpiration(id: unblock.id, at: unblock.endDate)
        }
    }

    func reconcile(screenTimeService: any ScreenTimeProviding) {
        for unblock in sharedStore.loadTimedUnblocks() {
            if unblock.endDate > .now {
                activeUnblocks[unblock.id] = unblock.endDate
                scheduleExpiration(id: unblock.id, at: unblock.endDate)
            } else {
                reapplyShield(for: unblock, screenTimeService: screenTimeService)
                sharedStore.removeTimedUnblock(id: unblock.id)
            }
        }
    }

    private func reapplyShield(
        for unblock: TimedUnblockDTO,
        screenTimeService: any ScreenTimeProviding
    ) {
        guard let selection = try? FamilyActivitySelection.fromData(unblock.selectionData)
        else { return }

        if unblock.isGroupUnblock {
            guard !sharedStore.isMainTimedUnblockActive() else { return }
            screenTimeService.addToShields(selection: selection)
        } else {
            screenTimeService.applyShieldOnAll(
                selection: selection,
                blockAllPreventsAppDelete: unblock.blockAllPreventsAppDelete ?? false
            )
        }
    }
}
