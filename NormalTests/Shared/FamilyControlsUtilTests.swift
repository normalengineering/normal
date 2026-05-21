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

    // MARK: - selectedTokenCounts

    @Test func emptyCountsReturnEmptyStatePhrase() {
        #expect(FamilyActivitySelection.selectedTokenCounts(apps: 0, websites: 0, categories: 0)
            == String(localized: "No items selected"))
    }

    @Test func emptySelectionReturnsEmptyStatePhrase() {
        #expect(FamilyActivitySelection().selectedTokenCounts == String(localized: "No items selected"))
    }

    @Test func singleAppUsesSingularNoun() {
        #expect(FamilyActivitySelection.selectedTokenCounts(apps: 1, websites: 0, categories: 0)
            == String(localized: "1 App"))
    }

    @Test func multipleAppsUsePluralNoun() {
        #expect(FamilyActivitySelection.selectedTokenCounts(apps: 5, websites: 0, categories: 0)
            == String(localized: "\(5) Apps"))
    }

    @Test func singleWebsiteUsesSingularNoun() {
        #expect(FamilyActivitySelection.selectedTokenCounts(apps: 0, websites: 1, categories: 0)
            == String(localized: "1 Website"))
    }

    @Test func multipleWebsitesUsePluralNoun() {
        #expect(FamilyActivitySelection.selectedTokenCounts(apps: 0, websites: 3, categories: 0)
            == String(localized: "\(3) Websites"))
    }

    @Test func singleCategoryUsesSingularNoun() {
        #expect(FamilyActivitySelection.selectedTokenCounts(apps: 0, websites: 0, categories: 1)
            == String(localized: "1 Category"))
    }

    @Test func multipleCategoriesUsePluralNoun() {
        #expect(FamilyActivitySelection.selectedTokenCounts(apps: 0, websites: 0, categories: 4)
            == String(localized: "\(4) Categories"))
    }

    @Test func allPluralSegmentsJoinInAppsWebsitesCategoriesOrder() {
        let summary = FamilyActivitySelection.selectedTokenCounts(apps: 2, websites: 3, categories: 4)
        let apps = String(localized: "\(2) Apps")
        let websites = String(localized: "\(3) Websites")
        let categories = String(localized: "\(4) Categories")
        #expect(summary == "\(apps), \(websites), \(categories)")
    }

    @Test func singularAndPluralCoexistInSameSummary() {
        let summary = FamilyActivitySelection.selectedTokenCounts(apps: 1, websites: 5, categories: 1)
        let app = String(localized: "1 App")
        let websites = String(localized: "\(5) Websites")
        let category = String(localized: "1 Category")
        #expect(summary == "\(app), \(websites), \(category)")
    }

    @Test func zeroSegmentsAreOmittedFromMixedSummary() {
        let summary = FamilyActivitySelection.selectedTokenCounts(apps: 5, websites: 0, categories: 3)
        let apps = String(localized: "\(5) Apps")
        let categories = String(localized: "\(3) Categories")
        #expect(summary == "\(apps), \(categories)")
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
