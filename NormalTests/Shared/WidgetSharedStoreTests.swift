import FamilyControls
import Foundation
@testable import Normal
import Testing

struct WidgetSharedStoreTests {
    private func makeStore() -> (WidgetSharedStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return (WidgetSharedStore(defaults: defaults), defaults)
    }

    private func group(_ name: String, sortIndex: Int = 0, id: UUID = UUID()) -> WidgetGroupDTO {
        WidgetGroupDTO(id: id, name: name, sortIndex: sortIndex)
    }

    @Test func loadEmptyReturnsEmpty() {
        let (store, _) = makeStore()
        #expect(store.loadGroups().isEmpty)
    }

    @Test func saveAndLoadRoundTrips() {
        let (store, _) = makeStore()
        store.saveGroups([group("Social"), group("Games", sortIndex: 1)])
        let loaded = store.loadGroups()
        #expect(loaded.map(\.name) == ["Social", "Games"])
    }

    @Test func loadSortsBySortIndex() {
        let (store, _) = makeStore()
        store.saveGroups([
            group("C", sortIndex: 2),
            group("A", sortIndex: 0),
            group("B", sortIndex: 1),
        ])
        #expect(store.loadGroups().map(\.name) == ["A", "B", "C"])
    }

    @Test func groupByIdFindsMatch() {
        let (store, _) = makeStore()
        let target = group("Social")
        store.saveGroups([group("Games"), target])
        #expect(store.group(id: target.id)?.name == "Social")
    }

    @Test func groupByIdReturnsNilWhenMissing() {
        let (store, _) = makeStore()
        store.saveGroups([group("Games")])
        #expect(store.group(id: UUID()) == nil)
    }

    @Test func timedUnblockEndReturnsStoredExpiry() throws {
        let (store, defaults) = makeStore()
        let groupID = UUID()
        let end = Date.now.addingTimeInterval(.hours(1))
        try writeGroupUnblock(into: defaults, groupID: groupID, endDate: end)

        let read = try #require(store.timedUnblockEnd(forGroupId: groupID))
        #expect(abs(read.timeIntervalSince(end)) < 1)
    }

    @Test func timedUnblockEndReturnsExpiredRecord() throws {
        let (store, defaults) = makeStore()
        let groupID = UUID()
        let end = Date.now.addingTimeInterval(-.minutes(1))
        try writeGroupUnblock(into: defaults, groupID: groupID, endDate: end)
        let read = try #require(store.timedUnblockEnd(forGroupId: groupID))
        #expect(abs(read.timeIntervalSince(end)) < 1)
    }

    @Test func timedUnblockEndNilWhenNoUnblock() {
        let (store, _) = makeStore()
        #expect(store.timedUnblockEnd(forGroupId: UUID()) == nil)
    }

    @Test func blockStatusRoundTrips() {
        let (store, _) = makeStore()
        let id = UUID()
        store.saveBlockStatuses([id.uuidString: WidgetBlockStatus.unblocked.rawValue])
        #expect(store.blockStatus(forGroupId: id) == .unblocked)
    }

    @Test func blockStatusNilWhenMissing() {
        let (store, _) = makeStore()
        #expect(store.blockStatus(forGroupId: UUID()) == nil)
    }

    @Test func groupStateUnblockedFromMirroredShieldState() {
        let (store, _) = makeStore()
        let id = UUID()
        store.saveBlockStatuses([id.uuidString: WidgetBlockStatus.unblocked.rawValue])
        #expect(store.groupState(forGroupId: id) == .unblocked(until: nil))
    }

    @Test func groupStateBlockedFromMirroredShieldState() {
        let (store, _) = makeStore()
        let id = UUID()
        store.saveBlockStatuses([id.uuidString: WidgetBlockStatus.blocked.rawValue])
        #expect(store.groupState(forGroupId: id) == .blocked)
    }

    @Test func groupStateActiveTimedUnblockWinsWithCountdown() throws {
        let (store, defaults) = makeStore()
        let id = UUID()
        let end = Date.now.addingTimeInterval(.hours(1))
        store.saveBlockStatuses([id.uuidString: WidgetBlockStatus.unblocked.rawValue])
        try writeGroupUnblock(into: defaults, groupID: id, endDate: end)
        #expect(store.groupState(forGroupId: id).countdownEnd != nil)
        #expect(store.groupState(forGroupId: id).isUnblocked)
    }

    @Test func groupStateExpiredTimedUnblockReadsAsBlockedDespiteStaleMirror() throws {
        let (store, defaults) = makeStore()
        let id = UUID()
        store.saveBlockStatuses([id.uuidString: WidgetBlockStatus.unblocked.rawValue])
        try writeGroupUnblock(into: defaults, groupID: id, endDate: .now.addingTimeInterval(-.minutes(1)))
        #expect(store.groupState(forGroupId: id) == .blocked)
    }

    @Test func keyTypesRoundTrip() {
        let (store, _) = makeStore()
        store.saveKeyTypes([KeyType.qr.rawValue])
        #expect(store.loadKeyTypes() == ["QR"])
    }

    @Test func keyTypesDefaultToEmpty() {
        let (store, _) = makeStore()
        #expect(store.loadKeyTypes().isEmpty)
    }

    @Test func keyTypesPreserveOrderAndOverwrite() {
        let (store, _) = makeStore()
        store.saveKeyTypes([KeyType.nfc.rawValue, KeyType.qr.rawValue])
        #expect(store.loadKeyTypes() == ["NFC", "QR"])
        store.saveKeyTypes([KeyType.qr.rawValue])
        #expect(store.loadKeyTypes() == ["QR"], "Saving replaces the previous set")
    }

    @Test func selectableKeyTypesRoundTripForWidgetPicker() {
        let (store, _) = makeStore()
        let selectable = KeyType.selectable(registered: [.nfc, .qr], onDevice: [.qr])
        store.saveKeyTypes(selectable.map(\.rawValue))
        #expect(store.loadKeyTypes() == ["QR"])
    }

    private func writeGroupUnblock(into defaults: UserDefaults, groupID: UUID, endDate: Date) throws {
        let dto = try TimedUnblockDTO(
            id: groupID.uuidString,
            selectionData: FamilyActivitySelection().toData(),
            endDate: endDate,
            activityName: SharedConstants.groupTimedUnblockActivityName(for: groupID),
            isGroupUnblock: true
        )
        SharedStore(defaults: defaults).upsertTimedUnblock(dto)
    }
}
