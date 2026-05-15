@testable import Normal
import FamilyControls
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
}
