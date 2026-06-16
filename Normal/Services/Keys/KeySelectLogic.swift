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
        defaultKeyType: KeyType?
    ) -> KeySelectAction {
        guard !availableKeyTypes.isEmpty else {
            return .showNoKeysAlert
        }

        guard !allowBypass else {
            return .showSheet
        }

        if let keyType = defaultKeyType, availableKeyTypes.contains(keyType), keyType.autoSelectable {
            return .autoSelect(keyType)
        }

        if availableKeyTypes.count == 1, availableKeyTypes[0].autoSelectable {
            return .autoSelect(availableKeyTypes[0])
        }

        return .showSheet
    }
}
