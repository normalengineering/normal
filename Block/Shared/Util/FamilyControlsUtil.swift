import FamilyControls

func tokenToHashableArray<T: Hashable>(tokens: Set<T>) -> [AnyHashable] {
    return Array(tokens) as [AnyHashable]
}

func allTokensFromSelection(selection: FamilyActivitySelection) -> [AnyHashable] {
    let categories = tokenToHashableArray(tokens: selection.categoryTokens)
    let apps = tokenToHashableArray(tokens: selection.applicationTokens)
    let webDomains = tokenToHashableArray(tokens: selection.webDomainTokens)

    return categories + apps + webDomains
}
