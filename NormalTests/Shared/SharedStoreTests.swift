import FamilyControls
import Foundation
@testable import Normal
import Testing

struct SharedStoreTests {
    private func makeStore() -> (SharedStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = SharedStore(defaults: defaults)
        return (store, defaults)
    }

    private func makeDTO(id: String, endDate: Date = .now.addingTimeInterval(.hours(1))) -> TimedUnblockDTO {
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
        store.upsertTimedUnblock(makeDTO(id: "main", endDate: .now.addingTimeInterval(.minutes(1))))
        store.upsertTimedUnblock(makeDTO(id: "main", endDate: .now.addingTimeInterval(.hours(1))))
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
        store.upsertTimedUnblock(makeDTO(id: "main", endDate: .now.addingTimeInterval(.hours(1))))
        #expect(store.isMainTimedUnblockActive())

        store.upsertTimedUnblock(makeDTO(id: "main", endDate: .now.addingTimeInterval(-.minutes(1))))
        #expect(!store.isMainTimedUnblockActive())
    }

    @Test func savesAndLoadsSchedules() throws {
        let (store, _) = makeStore()
        let dto = try ScheduleDTO(
            id: UUID(),
            name: "Test",
            selectionData: FamilyActivitySelection().toData(),
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

    @Test func scheduleOverrideFlagRoundTrips() {
        let (store, _) = makeStore()
        #expect(!store.isScheduleOverrideActive(), "Defaults to off")

        store.setScheduleOverrideActive(true)
        #expect(store.isScheduleOverrideActive())

        store.setScheduleOverrideActive(false)
        #expect(!store.isScheduleOverrideActive())
    }

    @Test func unblockAllInEffectReflectsTimedOrOverride() {
        let (store, _) = makeStore()
        #expect(!store.isUnblockAllInEffect())

        store.setScheduleOverrideActive(true)
        #expect(store.isUnblockAllInEffect(), "Permanent override counts")

        store.setScheduleOverrideActive(false)
        store.upsertTimedUnblock(makeDTO(id: "main"))
        #expect(store.isUnblockAllInEffect(), "Live timed unblock counts")
    }

    @Test func resolveScheduleStartAppliesWhenNothingActive() {
        let (store, _) = makeStore()
        #expect(store.resolveScheduleStart() == .apply)
    }

    @Test func resolveScheduleStartConsumesPermanentOverrideThenApplies() {
        let (store, _) = makeStore()
        store.setScheduleOverrideActive(true)

        #expect(store.resolveScheduleStart() == .apply, "The start proceeds (override ends here)")
        #expect(!store.isScheduleOverrideActive(), "...and the one-shot override is consumed")
        #expect(store.resolveScheduleStart() == .apply, "Subsequent starts apply normally")
    }

    @Test func resolveScheduleStartSkipsDuringTimedUnblockWithoutConsumingOverride() {
        let (store, _) = makeStore()
        store.upsertTimedUnblock(makeDTO(id: "main"))
        store.setScheduleOverrideActive(true)

        #expect(store.resolveScheduleStart() == .skip, "A live timed unblock wins for its whole window")
        #expect(store.isScheduleOverrideActive(),
                "A timed-unblock skip must not consume the permanent override")
    }
}
