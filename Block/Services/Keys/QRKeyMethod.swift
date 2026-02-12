import Foundation

struct QRKeyMethod: KeyMethod {
    let qrService: QRService
    let keys: [Key]

    func checkKey() async -> KeyResult {
        do {
            _ = try await qrService.scan { scannedValue in
                Key.matchingKeyExists(keys: keys, unhashedId: scannedValue)
            }
            return .success
        } catch {
            if case ScanError.userCanceled = error { return .cancelled }
            if case ScanError.invalidKey = error { return .failure }
            return .failure
        }
    }
}
