@testable import Normal
import FamilyControls
import Foundation
import Testing

struct SharedStoreTests {
    private func makeTestStore() -> SharedStore {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return SharedStore(defaults: defaults)
    }

    @Test func emptyLoadReturnsEmptyArray() {
        let store = makeTestStore()
        #expect(store.loadTimedUnblocks().isEmpty)
        #expect(store.loadSchedules().isEmpty)
    }

    @Test func upsertAndLoadTimedUnblock() throws {
        let store = makeTestStore()
        let selection = FamilyActivitySelection()
        let dto = try TimedUnblockDTO(
            id: "test1",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(3600),
            activityName: "activity_1",
            isGroupUnblock: false
        )

        store.upsertTimedUnblock(dto)
        let loaded = store.loadTimedUnblocks()

        #expect(loaded.count == 1)
        #expect(loaded.first?.id == "test1")
    }

    @Test func upsertReplacesSameId() throws {
        let store = makeTestStore()
        let selection = FamilyActivitySelection()

        let dto1 = try TimedUnblockDTO(
            id: "same",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(3600),
            activityName: "activity_1",
            isGroupUnblock: false
        )
        let dto2 = try TimedUnblockDTO(
            id: "same",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(7200),
            activityName: "activity_2",
            isGroupUnblock: true
        )

        store.upsertTimedUnblock(dto1)
        store.upsertTimedUnblock(dto2)
        let loaded = store.loadTimedUnblocks()

        #expect(loaded.count == 1)
        #expect(loaded.first?.activityName == "activity_2")
    }

    @Test func removeTimedUnblock() throws {
        let store = makeTestStore()
        let selection = FamilyActivitySelection()
        let dto = try TimedUnblockDTO(
            id: "remove-me",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(3600),
            activityName: "activity_rm",
            isGroupUnblock: false
        )

        store.upsertTimedUnblock(dto)
        store.removeTimedUnblock(id: "remove-me")

        #expect(store.loadTimedUnblocks().isEmpty)
    }

    @Test func findTimedUnblockByActivityName() throws {
        let store = makeTestStore()
        let selection = FamilyActivitySelection()
        let dto = try TimedUnblockDTO(
            id: "find-me",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(3600),
            activityName: "unique_activity",
            isGroupUnblock: false
        )

        store.upsertTimedUnblock(dto)
        let found = store.findTimedUnblock(activityName: "unique_activity")

        #expect(found?.id == "find-me")
        #expect(store.findTimedUnblock(activityName: "nonexistent") == nil)
    }

    @Test func isMainTimedUnblockActiveTrue() throws {
        let store = makeTestStore()
        let selection = FamilyActivitySelection()
        let dto = try TimedUnblockDTO(
            id: "main",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(3600),
            activityName: "main_activity",
            isGroupUnblock: false
        )

        store.upsertTimedUnblock(dto)
        #expect(store.isMainTimedUnblockActive())
    }

    @Test func isMainTimedUnblockActiveFalseWhenExpired() throws {
        let store = makeTestStore()
        let selection = FamilyActivitySelection()
        let dto = try TimedUnblockDTO(
            id: "main",
            selectionData: selection.toData(),
            endDate: Date.now.addingTimeInterval(-100),
            activityName: "main_activity",
            isGroupUnblock: false
        )

        store.upsertTimedUnblock(dto)
        #expect(!store.isMainTimedUnblockActive())
    }

    @Test func saveAndLoadSchedules() throws {
        let store = makeTestStore()
        let selection = FamilyActivitySelection()
        let dtos = [
            ScheduleDTO(
                id: UUID(),
                name: "Morning",
                selectionData: try selection.toData(),
                startHour: 8,
                startMinute: 0,
                durationMinutes: 60,
                weekdays: [2, 3, 4, 5, 6],
                shouldBlock: true,
                isTimed: true
            ),
            ScheduleDTO(
                id: UUID(),
                name: "Evening",
                selectionData: try selection.toData(),
                startHour: 20,
                startMinute: 0,
                durationMinutes: 120,
                weekdays: [1, 7],
                shouldBlock: false,
                isTimed: false
            ),
        ]

        store.saveSchedules(dtos)
        let loaded = store.loadSchedules()

        #expect(loaded.count == 2)
        #expect(loaded[0].name == "Morning")
        #expect(loaded[1].name == "Evening")
    }
}
