import FamilyControls
@testable import Normal
import Testing

struct FamilyControlsUtilTests {
    @Test func emptySelectionIsEmpty() {
        #expect(FamilyActivitySelection().isEmpty)
    }

    @Test func optionalNilSelectionIsEmpty() {
        let none: FamilyActivitySelection? = nil
        #expect(none.isEmpty)
        #expect(none.count == 0)
        #expect(none.allTokens.isEmpty)
    }

    @Test func optionalSomeEmptySelectionIsEmpty() {
        let some: FamilyActivitySelection? = FamilyActivitySelection()
        #expect(some.isEmpty)
    }

    @Test func emptySelectionHasZeroCount() {
        #expect(FamilyActivitySelection().count == 0)
    }

    @Test func emptySelectionIsSubsetOfEmpty() {
        let a = FamilyActivitySelection()
        let b = FamilyActivitySelection()
        #expect(a.isSubset(of: b))
    }

    @Test func sortedStablyIsAlphabeticalForStrings() {
        let tokens: [AnyHashable] = ["b", "a", "c"]
        let sorted = tokens.sortedStably
        #expect(sorted == ["a", "b", "c"] as [AnyHashable])
    }

    @Test func sortedStablyIsIdempotent() {
        let tokens: [AnyHashable] = ["b", "a", "c"]
        let firstPass = tokens.sortedStably
        let secondPass = firstPass.sortedStably
        #expect(firstPass == secondPass)
    }

    @Test func setSortedStablyIsDeterministic() {
        struct CodableValue: Hashable, Codable {
            let id: Int
        }
        let set: Set<CodableValue> = [.init(id: 3), .init(id: 1), .init(id: 2)]
        let firstPass = set.sortedStably
        let secondPass = set.sortedStably
        #expect(firstPass == secondPass)
        #expect(firstPass.count == 3)
    }

    @Test func allTokensFromEmptySelectionIsEmpty() {
        #expect(FamilyActivitySelection().allTokens.isEmpty)
    }

    @Test func emptySetAsHashableArrayIsEmpty() {
        let result = Set<Int>().asHashableArray
        #expect(result.isEmpty)
    }

    @Test func setWithValuesProducesHashableArray() {
        let result = Set<Int>([1, 2, 3]).asHashableArray
        #expect(result.count == 3)
    }

    @Test func summaryForAllZeroReturnsEmptyStateString() {
        let summary = FamilyActivitySelection.selectedTokenCounts(apps: 0, websites: 0, categories: 0)
        #expect(summary == String(localized: "No items selected"))
    }

    @Test func summaryOmitsZeroSegments() {
        let summary = FamilyActivitySelection.selectedTokenCounts(apps: 5, websites: 0, categories: 0)
        #expect(summary.contains("5"))
        #expect(!summary.contains("Website"))
        #expect(!summary.contains("Categor"))
    }

    @Test func summaryIncludesAllNonZeroSegments() {
        let summary = FamilyActivitySelection.selectedTokenCounts(apps: 30, websites: 5, categories: 2)
        #expect(summary.contains("30"))
        #expect(summary.contains("App"))
        #expect(summary.contains("5"))
        #expect(summary.contains("Website"))
        #expect(summary.contains("2"))
        #expect(summary.contains("Categor"))
    }

    @Test func summaryShowsCategoriesAloneWhenOnlyCategoriesSelected() {
        let summary = FamilyActivitySelection.selectedTokenCounts(apps: 0, websites: 0, categories: 4)
        #expect(summary.contains("4"))
        #expect(summary.contains("Categor"))
        #expect(!summary.contains("App"))
        #expect(!summary.contains("Website"))
    }

    @Test func summaryInflectsSingularDifferentlyFromPlural() {
        let singular = FamilyActivitySelection.selectedTokenCounts(apps: 1, websites: 0, categories: 0)
        let plural = FamilyActivitySelection.selectedTokenCounts(apps: 5, websites: 0, categories: 0)
        
        let singularNoun = singular.replacingOccurrences(of: "1", with: "")
        let pluralNoun = plural.replacingOccurrences(of: "5", with: "")
        #expect(singularNoun != pluralNoun)
    }

    @Test func emptySelectionProducesEmptyStateSummary() {
        #expect(FamilyActivitySelection().selectedTokenCounts == String(localized: "No items selected"))
    }

    @Test func tokenKindReturnsNilForUnknownHashable() {
        let unknown: AnyHashable = "not-a-token"
        #expect(SelectedTokenKind(unknown) == nil)
    }

    @Test func tokenKindReturnsNilForIntHashable() {
        let unknown: AnyHashable = 42
        #expect(SelectedTokenKind(unknown) == nil)
    }
}
