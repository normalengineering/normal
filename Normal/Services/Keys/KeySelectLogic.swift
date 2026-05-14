import Foundation

enum KeySelectAction: Equatable {
    case showNoKeysAlert
    case autoSelect(KeyType)
    case showSheet
}

enum KeySelectLogic {
    /// Decides what to do when the user triggers a block/unblock action.
    ///
    /// Auto-selection (skipping the sheet) is only allowed for NFC, because NFC
    /// uses the system dialog and doesn't need the key-select sheet.  QR always
    /// requires the sheet so the camera scanner can be presented.
    static func decide(
        availableKeyTypes: [KeyType],
        allowBypass: Bool,
        defaultKeyType: KeyType?
    ) -> KeySelectAction {
        guard !availableKeyTypes.isEmpty else {
            return .showNoKeysAlert
        }

        // Block actions (allowBypass = true) always show the sheet so the user
        // can choose "Block without key".
        guard !allowBypass else {
            return .showSheet
        }

        // Auto-select only when the key type is NFC (system dialog, no UI sheet needed).
        if let keyType = defaultKeyType, availableKeyTypes.contains(keyType), keyType == .nfc {
            return .autoSelect(keyType)
        }

        if availableKeyTypes.count == 1, availableKeyTypes[0] == .nfc {
            return .autoSelect(.nfc)
        }

        return .showSheet
    }
}
