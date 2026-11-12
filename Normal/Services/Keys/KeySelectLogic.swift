import Foundation

enum KeySelectAction: Equatable {
    case showNoKeysAlert
    case autoSelect(KeyType)
    case showSheet
}

enum KeySelectLogic {
    static func decide(
        availableKeyTypes: [KeyType],
        allowBypass: Bool,
        defaultKeyType: KeyType?,
        requestedKeyType: KeyType? = nil
    ) -> KeySelectAction {
        guard !availableKeyTypes.isEmpty else {
            return .showNoKeysAlert
        }

        guard !allowBypass else {
            return .showSheet
        }

        if let requestedKeyType, availableKeyTypes.contains(requestedKeyType) {
            return .autoSelect(requestedKeyType)
        }

        if let keyType = defaultKeyType, availableKeyTypes.contains(keyType), keyType.autoSelectable {
            return .autoSelect(keyType)
        }

        if availableKeyTypes.count == 1, availableKeyTypes[0].autoSelectable {
            return .autoSelect(availableKeyTypes[0])
        }

        return .showSheet
    }

    static func shortcutKeyType(
        requested: KeyType?,
        defaultKeyType: KeyType?,
        availableKeyTypes: [KeyType]
    ) -> KeyType? {
        if let requested {
            return requested
        }
        if let defaultKeyType, availableKeyTypes.contains(defaultKeyType) {
            return defaultKeyType
        }
        return availableKeyTypes.count == 1 ? availableKeyTypes[0] : nil
    }
}
