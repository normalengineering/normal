import Foundation

struct NFCKeyMethod: KeyMethod {
    let nfcService: NFCService
    let keys: [Key]

    func checkKey() async -> KeyResult {
        do {
            _ = try await nfcService.scan { tagId in
                Key.matchingKeyExists(keys: keys, unhashedId: tagId)
            }
            return .success
        } catch {
            if case ScanError.userCanceled = error { return .cancelled }
            if case ScanError.invalidKey = error { return .failure }
            return .failure
        }
    }
}
