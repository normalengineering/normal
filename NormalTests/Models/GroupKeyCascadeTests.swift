import FamilyControls
import Foundation
@testable import Normal
import SwiftData
import Testing

@MainActor
struct GroupKeyCascadeTests {
    private static let models: [any PersistentModel.Type] = [
        Key.self, Settings.self, BlockSchedule.self, SelectedApps.self, AppGroup.self,
    ]

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(Self.models),
            configurations: ModelConfiguration(schema: Schema(Self.models), isStoredInMemoryOnly: true)
        )
    }

    @Test func deletingGroupKeysLeavesGlobalAndOtherGroupsIntact() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groupA = AppGroup(name: "A", selection: FamilyActivitySelection())
        let groupB = AppGroup(name: "B", selection: FamilyActivitySelection())
        context.insert(groupA)
        context.insert(groupB)

        context.insert(Key(name: "global", type: .qr, rawValue: "g"))
        context.insert(Key(name: "a1", type: .qr, rawValue: "a1", groupID: groupA.id))
        context.insert(Key(name: "a2", type: .nfc, rawValue: "a2", groupID: groupA.id))
        context.insert(Key(name: "b1", type: .qr, rawValue: "b1", groupID: groupB.id))
        try context.save()

        let allKeys = try context.fetch(FetchDescriptor<Key>())
        groupA.deleteCascading(keys: allKeys, from: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Key>())
        #expect(Set(remaining.map(\.name)) == ["global", "b1"])
        #expect(remaining.allSatisfy { $0.groupID != groupA.id })
    }
}
