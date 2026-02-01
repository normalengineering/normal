import FamilyControls

func tokenToHashableArray<T: Hashable>(tokens: Set<T>) -> [AnyHashable] {
    return Array(tokens) as [AnyHashable]
}

func allTokensFromSelection(selection: FamilyActivitySelection) -> [AnyHashable] {
    let apps = tokenToHashableArray(tokens: selection.applicationTokens)
    let webDomains = tokenToHashableArray(tokens: selection.webDomainTokens)

    return apps + webDomains
}

func isSelectionEmpty(selection: FamilyActivitySelection?) -> Bool {
    guard let selection = selection else { return true }
    return selection.applicationTokens.isEmpty &&
        selection.webDomainTokens.isEmpty
}
