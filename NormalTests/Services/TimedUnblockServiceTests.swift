@testable import Normal
import FamilyControls
import Foundation
import Testing

struct TimedUnblockServiceTests {
    @MainActor
    private func makeSUT(
        preloadedUnblocks: [TimedUnblockDTO] = []
    ) -> (TimedUnblockService, MockDeviceActivityCenter, MockSharedStore, MockScreenTimeService) {
        let activityCenter = MockDeviceActivityCenter()
        let sharedStore = MockSharedStore()
        sharedStore.timedUnblocks = preloadedUnblocks
        let screenTimeService = MockScreenTimeService()
        let service = TimedUnblockService(
            activityCenter: activityCenter,
            sharedStore: sharedStore,
            onExpiration: {}
        )
        return (service, activityCenter, sharedStore, screenTimeService)
    }

    @Test @MainActor func initialStateIsInactive() {
        let (service, _, _, _) = makeSUT()
        #expect(!service.isMainUnblockActive)
        #expect(service.mainUnblockEndDate == nil)
    }

    @Test @MainActor func startMainRemovesShieldsAndSchedulesMonitoring() throws {
        let (service, activityCenter, sharedStore, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: selection,
            screenTimeService: screenTimeService
        )

        #expect(screenTimeService.removeShieldOnAllCalled)
        #expect(activityCenter.startMonitoringCalled)
        #expect(sharedStore.timedUnblocks.count == 1)
        #expect(sharedStore.timedUnblocks.first?.id == "main")
    }

    @Test @MainActor func startMainSetsActiveUnblock() throws {
        let (service, _, _, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: selection,
            screenTimeService: screenTimeService
        )

        #expect(service.isMainUnblockActive)
        #expect(service.mainUnblockEndDate != nil)
    }

    @Test @MainActor func cancelMainReappliesShieldsAndStopsMonitoring() throws {
        let (service, activityCenter, sharedStore, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: selection,
            screenTimeService: screenTimeService
        )

        service.cancelMain(selection: selection, screenTimeService: screenTimeService)

        #expect(screenTimeService.applyShieldOnAllCalled)
        #expect(activityCenter.stopMonitoringCalled)
        #expect(!service.isMainUnblockActive)
        #expect(sharedStore.timedUnblocks.isEmpty)
    }

    @Test @MainActor func startGroupRemovesFromShields() throws {
        let (service, activityCenter, _, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()
        let groupId = UUID()

        try service.startGroup(
            duration: .thirtyMinutes,
            groupId: groupId,
            selection: selection,
            screenTimeService: screenTimeService
        )

        #expect(screenTimeService.removeFromShieldsCalled)
        #expect(activityCenter.startMonitoringCalled)
        #expect(service.isGroupUnblockActive(groupId: groupId))
        #expect(service.groupUnblockEndDate(groupId: groupId) != nil)
    }

    @Test @MainActor func cancelGroupAddsToShields() throws {
        let (service, _, sharedStore, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()
        let groupId = UUID()

        try service.startGroup(
            duration: .thirtyMinutes,
            groupId: groupId,
            selection: selection,
            screenTimeService: screenTimeService
        )

        service.cancelGroup(
            groupId: groupId,
            selection: selection,
            screenTimeService: screenTimeService
        )

        #expect(screenTimeService.addToShieldsCalled)
        #expect(!service.isGroupUnblockActive(groupId: groupId))
        #expect(sharedStore.timedUnblocks.isEmpty)
    }

    @Test @MainActor func startMainCancelsAllGroupUnblocks() throws {
        let (service, _, _, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()
        let group1 = UUID()
        let group2 = UUID()

        try service.startGroup(
            duration: .thirtyMinutes,
            groupId: group1,
            selection: selection,
            screenTimeService: screenTimeService
        )
        try service.startGroup(
            duration: .oneHour,
            groupId: group2,
            selection: selection,
            screenTimeService: screenTimeService
        )

        #expect(service.isGroupUnblockActive(groupId: group1))
        #expect(service.isGroupUnblockActive(groupId: group2))

        try service.startMain(
            duration: .fifteenMinutes,
            selection: selection,
            screenTimeService: screenTimeService
        )

        #expect(!service.isGroupUnblockActive(groupId: group1))
        #expect(!service.isGroupUnblockActive(groupId: group2))
        #expect(service.isMainUnblockActive)
    }

    @Test @MainActor func restoreStatePrunesExpired() throws {
        let selection = FamilyActivitySelection()
        let expiredDTO = try TimedUnblockDTO(
            id: "expired",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(-100),
            activityName: "expired_activity",
            isGroupUnblock: false
        )

        let (service, _, sharedStore, _) = makeSUT(preloadedUnblocks: [expiredDTO])

        #expect(service.activeUnblocks["expired"] == nil)
        #expect(sharedStore.timedUnblocks.isEmpty)
    }

    @Test @MainActor func restoreStateKeepsActive() throws {
        let selection = FamilyActivitySelection()
        let activeDTO = try TimedUnblockDTO(
            id: "main",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(3600),
            activityName: "main_activity",
            isGroupUnblock: false
        )

        let (service, _, _, _) = makeSUT(preloadedUnblocks: [activeDTO])

        #expect(service.isMainUnblockActive)
        #expect(service.mainUnblockEndDate != nil)
    }

    @Test @MainActor func startMainThrowsWhenMonitoringFails() {
        let activityCenter = MockDeviceActivityCenter()
        activityCenter.shouldThrowOnStart = true
        let sharedStore = MockSharedStore()
        let screenTimeService = MockScreenTimeService()
        let service = TimedUnblockService(
            activityCenter: activityCenter,
            sharedStore: sharedStore,
            onExpiration: {}
        )

        #expect(throws: Error.self) {
            try service.startMain(
                duration: .fifteenMinutes,
                selection: FamilyActivitySelection(),
                screenTimeService: screenTimeService
            )
        }
    }

    @Test @MainActor func startMainWithAllowAppDeleteDisablesAppDeletion() throws {
        let (service, _, _, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: selection,
            screenTimeService: screenTimeService,
            allowAppDelete: true
        )

        #expect(screenTimeService.removeShieldOnAllCalled)
        #expect(screenTimeService.removeShieldOnAllAllowAppDelete == true)
        #expect(screenTimeService.disablePreventAppDeleteCalled)
    }

    @Test @MainActor func startMainWithoutAllowAppDeleteDoesNotDisableAppDeletion() throws {
        let (service, _, _, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: selection,
            screenTimeService: screenTimeService,
            allowAppDelete: false
        )

        #expect(screenTimeService.removeShieldOnAllCalled)
        #expect(screenTimeService.removeShieldOnAllAllowAppDelete == false)
        #expect(!screenTimeService.disablePreventAppDeleteCalled)
    }

    @Test @MainActor func cancelMainWithPreventAppDeleteEnablesAppDeletion() throws {
        let (service, _, _, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: selection,
            screenTimeService: screenTimeService
        )

        service.cancelMain(
            selection: selection,
            screenTimeService: screenTimeService,
            preventAppDelete: true
        )

        #expect(screenTimeService.applyShieldOnAllCalled)
        #expect(screenTimeService.applyShieldOnAllPreventAppDelete == true)
        #expect(screenTimeService.enablePreventAppDeleteCalled)
    }

    @Test @MainActor func cancelMainWithoutPreventAppDeleteDoesNotEnableAppDeletion() throws {
        let (service, _, _, screenTimeService) = makeSUT()
        let selection = FamilyActivitySelection()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: selection,
            screenTimeService: screenTimeService
        )

        service.cancelMain(
            selection: selection,
            screenTimeService: screenTimeService,
            preventAppDelete: false
        )

        #expect(screenTimeService.applyShieldOnAllCalled)
        #expect(screenTimeService.applyShieldOnAllPreventAppDelete == false)
        #expect(!screenTimeService.enablePreventAppDeleteCalled)
    }

    @Test @MainActor func updateMainSelectionUpdatesSharedStore() throws {
        let (service, _, sharedStore, screenTimeService) = makeSUT()
        let originalSelection = FamilyActivitySelection()

        try service.startMain(
            duration: .fifteenMinutes,
            selection: originalSelection,
            screenTimeService: screenTimeService
        )

        let originalData = sharedStore.timedUnblocks.first?.selectionData

        let updatedSelection = FamilyActivitySelection()
        service.updateMainSelection(updatedSelection)

        #expect(sharedStore.timedUnblocks.count == 1)
        #expect(sharedStore.timedUnblocks.first?.id == "main")
        #expect(sharedStore.timedUnblocks.first?.selectionData != nil)
    }

    @Test @MainActor func updateMainSelectionNoOpWhenInactive() {
        let (service, _, sharedStore, _) = makeSUT()

        service.updateMainSelection(FamilyActivitySelection())

        #expect(sharedStore.timedUnblocks.isEmpty)
    }

    @Test @MainActor func updateGroupSelectionUpdatesSharedStore() throws {
        let (service, _, sharedStore, screenTimeService) = makeSUT()
        let groupId = UUID()
        let originalSelection = FamilyActivitySelection()

        try service.startGroup(
            duration: .thirtyMinutes,
            groupId: groupId,
            selection: originalSelection,
            screenTimeService: screenTimeService
        )

        let updatedSelection = FamilyActivitySelection()
        service.updateGroupSelection(groupId: groupId, selection: updatedSelection)

        #expect(sharedStore.timedUnblocks.count == 1)
        #expect(sharedStore.timedUnblocks.first?.id == groupId.uuidString)
    }

    @Test @MainActor func updateGroupSelectionNoOpWhenInactive() {
        let (service, _, sharedStore, _) = makeSUT()

        service.updateGroupSelection(groupId: UUID(), selection: FamilyActivitySelection())

        #expect(sharedStore.timedUnblocks.isEmpty)
    }
}
