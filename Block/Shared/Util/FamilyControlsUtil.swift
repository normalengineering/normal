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

func selectionCount(selection: FamilyActivitySelection?) -> Int {
    guard let selection = selection else { return 0 }
    return selection.applicationTokens.count + selection.webDomainTokens.count
}

func sortTokens(tokens: [AnyHashable]) -> [AnyHashable]{
    return tokens.sorted { String(describing: $0) < String(describing: $1) }
}
