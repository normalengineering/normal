@testable import Normal
import FamilyControls
import Testing

struct FamilyControlsUtilTests {
    @Test func isSelectionEmptyWithEmptySelection() {
        let selection = FamilyActivitySelection()
        #expect(isSelectionEmpty(selection: selection))
    }

    @Test func isSelectionEmptyWithNil() {
        #expect(isSelectionEmpty(selection: nil))
    }

    @Test func selectionCountZeroForEmpty() {
        let selection = FamilyActivitySelection()
        #expect(selectionCount(selection: selection) == 0)
    }

    @Test func selectionCountZeroForNil() {
        #expect(selectionCount(selection: nil) == 0)
    }

    @Test func allTokensFromEmptySelection() {
        let selection = FamilyActivitySelection()
        #expect(allTokensFromSelection(selection: selection).isEmpty)
    }

    @Test func isSelectionSyncedBothEmpty() {
        let a = FamilyActivitySelection()
        let b = FamilyActivitySelection()
        #expect(isSelectionSynced(selection: a, with: b))
    }
}
