@testable import Normal
import FamilyControls
import Foundation
import Testing

struct SharedStoreTests {
    private func makeStore() -> (SharedStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = SharedStore(defaults: defaults)
        return (store, defaults)
    }

    private func makeDTO(id: String, endDate: Date = .now.addingTimeInterval(3600)) -> TimedUnblockDTO {
        try! TimedUnblockDTO(
            id: id,
            selectionData: FamilyActivitySelection().toData(),
            endDate: endDate,
            activityName: "timedUnblock_\(id)",
            isGroupUnblock: id != "main"
        )
    }

    @Test func loadEmptyReturnsEmpty() {
        let (store, _) = makeStore()
        #expect(store.loadTimedUnblocks().isEmpty)
        #expect(store.loadSchedules().isEmpty)
    }

    @Test func saveAndLoadTimedUnblocks() {
        let (store, _) = makeStore()
        let dto = makeDTO(id: "main")
        store.saveTimedUnblocks([dto])
        #expect(store.loadTimedUnblocks().count == 1)
        #expect(store.loadTimedUnblocks().first?.id == "main")
    }

    @Test func upsertReplacesById() {
        let (store, _) = makeStore()
        store.upsertTimedUnblock(makeDTO(id: "main", endDate: .now.addingTimeInterval(60)))
        store.upsertTimedUnblock(makeDTO(id: "main", endDate: .now.addingTimeInterval(3600)))
        #expect(store.loadTimedUnblocks().count == 1)
    }

    @Test func upsertAppendsDistinctIds() {
        let (store, _) = makeStore()
        store.upsertTimedUnblock(makeDTO(id: "main"))
        store.upsertTimedUnblock(makeDTO(id: "group-1"))
        #expect(store.loadTimedUnblocks().count == 2)
    }

    @Test func removeTimedUnblockById() {
        let (store, _) = makeStore()
        store.upsertTimedUnblock(makeDTO(id: "main"))
        store.upsertTimedUnblock(makeDTO(id: "group-1"))
        store.removeTimedUnblock(id: "main")
        #expect(store.loadTimedUnblocks().map(\.id) == ["group-1"])
    }

    @Test func findTimedUnblockByActivityName() {
        let (store, _) = makeStore()
        store.upsertTimedUnblock(makeDTO(id: "main"))
        let found = store.findTimedUnblock(activityName: "timedUnblock_main")
        #expect(found?.id == "main")
    }

    @Test func mainActiveOnlyWhenFutureEndDate() {
        let (store, _) = makeStore()
        store.upsertTimedUnblock(makeDTO(id: "main", endDate: .now.addingTimeInterval(3600)))
        #expect(store.isMainTimedUnblockActive())

        store.upsertTimedUnblock(makeDTO(id: "main", endDate: .now.addingTimeInterval(-60)))
        #expect(!store.isMainTimedUnblockActive())
    }

    @Test func savesAndLoadsSchedules() throws {
        let (store, _) = makeStore()
        let dto = ScheduleDTO(
            id: UUID(),
            name: "Test",
            selectionData: try FamilyActivitySelection().toData(),
            startHour: 8,
            startMinute: 0,
            durationMinutes: 60,
            weekdays: [2, 3, 4, 5, 6],
            shouldBlock: true,
            isTimed: true
        )
        store.saveSchedules([dto])
        let loaded = store.loadSchedules()
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "Test")
    }
}
