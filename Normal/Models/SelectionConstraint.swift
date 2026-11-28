import FamilyControls
import Foundation

struct SelectionConstraint {
    let selection: FamilyActivitySelection
    let customDomains: [String]
    let customDomainsEnabled: Bool

    init(
        selection: FamilyActivitySelection,
        customDomains: [String],
        customDomainsEnabled: Bool = true
    ) {
        self.selection = selection
        self.customDomains = customDomains
        self.customDomainsEnabled = customDomainsEnabled
    }

    var effectiveCustomDomains: [String] {
        customDomainsEnabled ? customDomains : []
    }

    func intersect(_ otherSelection: FamilyActivitySelection) -> FamilyActivitySelection {
        otherSelection.intersection(selection)
    }

    func intersect(_ otherDomains: [String]) -> [String] {
        CustomDomains.subset(otherDomains, of: effectiveCustomDomains)
    }

    func needsSync(selection otherSelection: FamilyActivitySelection, customDomains otherDomains: [String]) -> Bool {
        if !otherSelection.isSubset(of: selection) {
            return true
        }
        if customDomainsEnabled, CustomDomains.needsResync(otherDomains, main: customDomains) {
            return true
        }
        return false
    }
}

extension SelectedApps {
    func effectiveConstraint(customDomainsEnabled: Bool) -> SelectionConstraint {
        SelectionConstraint(
            selection: selection,
            customDomains: customDomains,
            customDomainsEnabled: customDomainsEnabled
        )
    }
}
