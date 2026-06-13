@preconcurrency import CoreNFC

extension KeyType {
    var isAvailableOnDevice: Bool {
        switch self {
        case .nfc: NFCTagReaderSession.readingAvailable
        case .qr: true
        }
    }

    static var availableOnDevice: [KeyType] {
        allCases.filter(\.isAvailableOnDevice)
    }

    static func selectable(
        registered: some Sequence<KeyType>,
        onDevice: [KeyType] = KeyType.availableOnDevice
    ) -> [KeyType] {
        onDevice.filter { registered.contains($0) }
    }
}
