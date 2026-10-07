import FamilyControls
import Foundation
@testable import Normal
import Testing

@MainActor
struct WidgetSyncTests {
    @Test func renamingAGroupChangesItsMirroredDTOs() {
        let group = AppGroup(name: "Work", selection: FamilyActivitySelection())
        let before = WidgetSync.groupDTOs([group])

        group.name = "Focus"

        #expect(WidgetSync.groupDTOs([group]) != before)
        #expect(WidgetSync.groupDTOs([group]).first?.name == "Focus")
    }

    @Test func reorderingGroupsChangesTheirMirroredDTOs() {
        let first = AppGroup(name: "Work", selection: FamilyActivitySelection(), sortIndex: 0)
        let second = AppGroup(name: "Social", selection: FamilyActivitySelection(), sortIndex: 1)
        let before = WidgetSync.groupDTOs([first, second])

        first.sortIndex = 1
        second.sortIndex = 0

        #expect(WidgetSync.groupDTOs([first, second]) != before)
    }

    @Test func unchangedGroupsMirrorEqually() {
        let group = AppGroup(name: "Work", selection: FamilyActivitySelection())

        #expect(WidgetSync.groupDTOs([group]) == WidgetSync.groupDTOs([group]))
    }
}
