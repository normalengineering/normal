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
    private let clock: () -> Date

    private(set) var activeUnblocks: [String: Date] = [:]
    private var expirationTasks: [String: Task<Void, Never>] = [:]

    static let mainID = "main"

    init(
        activityCenter: any DeviceActivityProviding = DeviceActivityCenter(),
        sharedStore: any SharedStoreProviding = SharedStore(),
        clock: @escaping () -> Date = { .now },
        onExpiration: @escaping @MainActor @Sendable () -> Void
    ) {
        self.activityCenter = activityCenter
        self.sharedStore = sharedStore
        self.clock = clock
        self.onExpiration = onExpiration
        restoreState()
    }

    var isMainUnblockActive: Bool {
        activeUnblocks[Self.mainID] != nil
    }

    var mainUnblockEndDate: Date? {
        activeUnblocks[Self.mainID]
    }

    func activeUnblockStartDates() -> [String: Date] {
        var starts: [String: Date] = [:]
        for unblock in sharedStore.loadTimedUnblocks() where activeUnblocks[unblock.id] != nil {
            starts[unblock.id] = unblock.startDate
        }
        return starts
    }

    func isGroupUnblockActive(groupId: UUID) -> Bool {
        activeUnblocks[groupId.uuidString] != nil
    }

    func groupUnblockEndDate(groupId: UUID) -> Date? {
        activeUnblocks[groupId.uuidString]
    }

    func startMain(
        duration: TimedUnblockDuration,
        selection: FamilyActivitySelection,
        customDomains: [String] = [],
        screenTimeService: any ScreenTimeProviding,
        blockAllPreventsAppDelete: Bool = false
    ) throws {
        let activityName = SharedConstants.mainTimedUnblockActivityName
        cancelMonitoring(activityName: activityName)

        let start = clock()
        let endDate = start.addingTimeInterval(duration.timeInterval)
        try scheduleActivity(name: activityName, start: start, endDate: endDate)

        try persist(
            id: Self.mainID,
            selection: selection,
            customDomains: customDomains,
            startDate: start,
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: false,
            blockAllPreventsAppDelete: blockAllPreventsAppDelete
        )

        cancelAllGroupUnblocks()
        syncHeartbeat()
        screenTimeService.reconcile()
    }

    func startGroup(
        duration: TimedUnblockDuration,
        groupId: UUID,
        selection: FamilyActivitySelection,
        customDomains: [String] = [],
        screenTimeService: any ScreenTimeProviding
    ) throws {
        let id = groupId.uuidString
        let activityName = SharedConstants.groupTimedUnblockActivityName(for: groupId)
        cancelMonitoring(activityName: activityName)

        let start = clock()
        let endDate = start.addingTimeInterval(duration.timeInterval)
        try scheduleActivity(name: activityName, start: start, endDate: endDate)

        try persist(
            id: id,
            selection: selection,
            customDomains: customDomains,
            startDate: start,
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: true
        )

        syncHeartbeat()
        screenTimeService.reconcile()
    }

    func cancelMain(
        selection: FamilyActivitySelection,
        customDomains: [String] = [],
        screenTimeService: any ScreenTimeProviding,
        blockAllPreventsAppDelete: Bool = false
    ) {
        cancelMonitoring(activityName: SharedConstants.mainTimedUnblockActivityName)
        cancelAllGroupUnblocks()
        forget(id: Self.mainID)
        syncHeartbeat()
        screenTimeService.blockAll(
            selection: selection,
            customDomains: customDomains,
            blockAllPreventsAppDelete: blockAllPreventsAppDelete
        )
    }

    func cancelGroup(groupId: UUID) {
        cancelMonitoring(activityName: SharedConstants.groupTimedUnblockActivityName(for: groupId))
        forget(id: groupId.uuidString)
        syncHeartbeat()
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
        syncHeartbeat()
    }

    func discardAll() {
        let activityNames = Set(
            sharedStore.loadTimedUnblocks().map(\.activityName)
                + activeUnblocks.keys.map { key in
                    UUID(uuidString: key).map(SharedConstants.groupTimedUnblockActivityName(for:))
                        ?? SharedConstants.mainTimedUnblockActivityName
                }
        )
        sharedStore.saveTimedUnblocks([])
        for key in Array(activeUnblocks.keys) {
            cancelExpiration(id: key)
        }
        activeUnblocks.removeAll()
        activityCenter.stopMonitoring(activityNames.map { DeviceActivityName($0) })
        syncHeartbeat()
    }

    func updateMainSelection(
        _ selection: FamilyActivitySelection,
        customDomains: [String] = [],
        screenTimeService: any ScreenTimeProviding
    ) {
        guard let endDate = activeUnblocks[Self.mainID] else { return }
        let activityName = SharedConstants.mainTimedUnblockActivityName
        let existing = sharedStore.findTimedUnblock(activityName: activityName)
        let previous = existing.flatMap { try? FamilyActivitySelection.fromData($0.selectionData) }
            ?? FamilyActivitySelection()
        screenTimeService.updateMainList(
            from: previous,
            customDomains: existing?.customDomains ?? [],
            to: selection,
            customDomains: customDomains,
            addedBlockedAsOf: (existing?.startDate ?? clock()).addingTimeInterval(-1)
        )
        try? persist(
            id: Self.mainID,
            selection: selection,
            customDomains: customDomains,
            startDate: existing?.startDate,
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: false,
            scheduleTask: false,
            blockAllPreventsAppDelete: existing?.blockAllPreventsAppDelete
        )
    }

    func updateGroupSelection(groupId: UUID, selection: FamilyActivitySelection, customDomains: [String] = []) {
        let id = groupId.uuidString
        guard let endDate = activeUnblocks[id] else { return }
        let activityName = SharedConstants.groupTimedUnblockActivityName(for: groupId)
        try? persist(
            id: id,
            selection: selection,
            customDomains: customDomains,
            startDate: sharedStore.findTimedUnblock(activityName: activityName)?.startDate,
            endDate: endDate,
            activityName: activityName,
            isGroupUnblock: true,
            scheduleTask: false
        )
    }

    private func persist(
        id: String,
        selection: FamilyActivitySelection,
        customDomains: [String],
        startDate: Date?,
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
            blockAllPreventsAppDelete: blockAllPreventsAppDelete,
            customDomains: customDomains,
            startDate: startDate
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

    private func syncHeartbeat() {
        activityCenter.syncHeartbeat(sharedStore: sharedStore, at: clock())
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
        for unblock in sharedStore.loadTimedUnblocks() where unblock.endDate > clock() {
            activeUnblocks[unblock.id] = unblock.endDate
            scheduleExpiration(id: unblock.id, at: unblock.endDate)
        }
    }

    func reconcile(screenTimeService: any ScreenTimeProviding) {
        screenTimeService.reconcile()
        for unblock in sharedStore.loadTimedUnblocks() {
            if unblock.endDate > clock() {
                activeUnblocks[unblock.id] = unblock.endDate
                scheduleExpiration(id: unblock.id, at: unblock.endDate)
            } else {
                sharedStore.removeTimedUnblock(id: unblock.id)
            }
        }
        syncHeartbeat()
    }
}

extension TimedUnblockService {
    func startMain(
        duration: TimedUnblockDuration,
        mainSelection: SelectedApps,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding
    ) throws {
        try startMain(
            duration: duration,
            selection: mainSelection.selection,
            customDomains: settings.enableCustomDomains ? mainSelection.customDomains : [],
            screenTimeService: screenTimeService,
            blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete
        )
    }
}
