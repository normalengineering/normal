import FamilyControls
import Foundation
@testable import Normal
import Testing

struct AppGroupTests {
    @Test func storesNameAndSelection() {
        let selection = FamilyActivitySelection()
        let group = AppGroup(name: "Social", selection: selection)
        #expect(group.name == "Social")
    }

    @Test func generatesUniqueIDs() {
        let a = AppGroup(name: "A", selection: FamilyActivitySelection())
        let b = AppGroup(name: "B", selection: FamilyActivitySelection())
        #expect(a.id != b.id)
    }

    @Test func lastUpdatedIsRecent() {
        let group = AppGroup(name: "G", selection: FamilyActivitySelection())
        #expect(abs(group.lastUpdated.timeIntervalSinceNow) < 1)
    }

    @Test func sortIndexDefaultsToZero() {
        let group = AppGroup(name: "G", selection: FamilyActivitySelection())
        #expect(group.sortIndex == 0)
    }

    @Test func sortIndexHonorsExplicitValue() {
        let group = AppGroup(name: "G", selection: FamilyActivitySelection(), sortIndex: 7)
        #expect(group.sortIndex == 7)
    }

    @Test func sortIndexIsMutable() {
        let group = AppGroup(name: "G", selection: FamilyActivitySelection())
        group.sortIndex = 42
        #expect(group.sortIndex == 42)
    }
}
