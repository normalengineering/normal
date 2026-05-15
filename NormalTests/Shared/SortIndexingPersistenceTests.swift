@testable import Normal
import FamilyControls
import Foundation
import SwiftData
import Testing

@MainActor
struct SortIndexingPersistenceTests {
    // MARK: - AppGroup

    @Test func appGroupsFetchInSortIndexOrderAfterReorder() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        let a = AppGroup(name: "A", selection: FamilyActivitySelection(), sortIndex: 0)
        let b = AppGroup(name: "B", selection: FamilyActivitySelection(), sortIndex: 1)
        let c = AppGroup(name: "C", selection: FamilyActivitySelection(), sortIndex: 2)
        [a, b, c].forEach(context.insert)
        try context.save()

        // Move "A" from position 0 to after "C" — expect order: B, C, A.
        let initial = try context.fetch(
            FetchDescriptor<AppGroup>(sortBy: [SortDescriptor(\.sortIndex)])
        )
        _ = SortIndexing.reorder(initial, from: IndexSet(integer: 0), to: 3)
        try context.save()

        let reloaded = try context.fetch(
            FetchDescriptor<AppGroup>(sortBy: [SortDescriptor(\.sortIndex)])
        )
        #expect(reloaded.map(\.name) == ["B", "C", "A"])
        #expect(reloaded.map(\.sortIndex) == [0, 1, 2])
    }

    @Test func nextIndexProducesAppendBehaviorForGroups() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        let existing = [
            AppGroup(name: "A", selection: FamilyActivitySelection(), sortIndex: 0),
            AppGroup(name: "B", selection: FamilyActivitySelection(), sortIndex: 1)
        ]
        existing.forEach(context.insert)

        let next = SortIndexing.nextIndex(after: existing)
        let new = AppGroup(name: "C", selection: FamilyActivitySelection(), sortIndex: next)
        context.insert(new)
        try context.save()

        let reloaded = try context.fetch(
            FetchDescriptor<AppGroup>(sortBy: [SortDescriptor(\.sortIndex)])
        )
        #expect(reloaded.map(\.name) == ["A", "B", "C"])
    }

    // MARK: - BlockSchedule

    @Test func schedulesFetchInSortIndexOrderAfterReorder() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        let morning = makeSchedule(name: "Morning", sortIndex: 0)
        let afternoon = makeSchedule(name: "Afternoon", sortIndex: 1)
        let evening = makeSchedule(name: "Evening", sortIndex: 2)
        [morning, afternoon, evening].forEach(context.insert)
        try context.save()

        // Move "Evening" (index 2) to the top.
        let initial = try context.fetch(
            FetchDescriptor<BlockSchedule>(sortBy: [SortDescriptor(\.sortIndex)])
        )
        _ = SortIndexing.reorder(initial, from: IndexSet(integer: 2), to: 0)
        try context.save()

        let reloaded = try context.fetch(
            FetchDescriptor<BlockSchedule>(sortBy: [SortDescriptor(\.sortIndex)])
        )
        #expect(reloaded.map(\.name) == ["Evening", "Morning", "Afternoon"])
        #expect(reloaded.map(\.sortIndex) == [0, 1, 2])
    }

    @Test func reorderPreservesUnaffectedItems() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        let items = (0 ..< 5).map { i in
            makeSchedule(name: "S\(i)", sortIndex: i)
        }
        items.forEach(context.insert)
        try context.save()

        // Swap S1 with S2.
        let initial = try context.fetch(
            FetchDescriptor<BlockSchedule>(sortBy: [SortDescriptor(\.sortIndex)])
        )
        _ = SortIndexing.reorder(initial, from: IndexSet(integer: 1), to: 3)
        try context.save()

        let reloaded = try context.fetch(
            FetchDescriptor<BlockSchedule>(sortBy: [SortDescriptor(\.sortIndex)])
        )
        #expect(reloaded.map(\.name) == ["S0", "S2", "S1", "S3", "S4"])
    }

    // MARK: - Helpers

    private func makeSchedule(name: String, sortIndex: Int) -> BlockSchedule {
        BlockSchedule(
            name: name,
            selection: FamilyActivitySelection(),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 60,
            weekdays: [2, 3, 4, 5, 6],
            sortIndex: sortIndex
        )
    }
}
