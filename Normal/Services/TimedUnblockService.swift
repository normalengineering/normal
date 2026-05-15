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
        allowAppDelete: Bool = false
    ) throws {
        let activityName = SharedConstants.mainTimedUnblockActivityName
        cancelMonitoring(activityName: activityName)
        cancelAllGroupUnblocks()

        let endDate = Date.now.addingTimeInterval(duration.timeInterval)
        screenTimeService.removeShieldOnAll(allowAppDelete: allowAppDelete)
        try scheduleActivity(name: activityName, endDate: endDate)

        try persist(
            id: Self.mainID,
            selection: selection,
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: false
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

        let endDate = Date.now.addingTimeInterval(duration.timeInterval)
        screenTimeService.removeFromShields(selection: selection)
        try scheduleActivity(name: activityName, endDate: endDate)

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
        preventAppDelete: Bool = false
    ) {
        cancelMonitoring(activityName: SharedConstants.mainTimedUnblockActivityName)
        screenTimeService.applyShieldOnAll(selection: selection, preventAppDelete: preventAppDelete)
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

    func updateMainSelection(_ selection: FamilyActivitySelection) {
        guard let endDate = activeUnblocks[Self.mainID] else { return }
        try? persist(
            id: Self.mainID,
            selection: selection,
            endDate: endDate,
            activityName: SharedConstants.mainTimedUnblockActivityName,
            isGroupUnblock: false,
            scheduleTask: false
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
        scheduleTask: Bool = true
    ) throws {
        let dto = try TimedUnblockDTO(
            id: id,
            selectionData: selection.toData(),
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: isGroupUnblock
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

    private func scheduleActivity(name: String, endDate: Date) throws {
        let calendar = Calendar.current
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: .now),
            intervalEnd: calendar.dateComponents(fields, from: endDate),
            repeats: false
        )
        try activityCenter.startMonitoring(
            DeviceActivityName(name),
            during: schedule,
            events: [:]
        )
    }

    func refresh() {
        for (_, task) in expirationTasks { task.cancel() }
        expirationTasks.removeAll()
        activeUnblocks.removeAll()
        restoreState()
    }

    private func restoreState() {
        for unblock in sharedStore.loadTimedUnblocks() {
            if unblock.endDate > .now {
                activeUnblocks[unblock.id] = unblock.endDate
                scheduleExpiration(id: unblock.id, at: unblock.endDate)
            } else {
                sharedStore.removeTimedUnblock(id: unblock.id)
            }
        }
    }
}
