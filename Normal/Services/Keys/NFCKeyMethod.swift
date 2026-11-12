import Foundation

struct NFCKeyMethod: KeyMethod {
    let nfcService: any KeyScanning
    let keys: [Key]

    func checkKey() async -> KeyResult {
        await performScanCheck(using: nfcService, against: keys)
    }
}

struct QRKeyMethod: KeyMethod {
    let qrService: any KeyScanning
    let keys: [Key]

    func checkKey() async -> KeyResult {
        await performScanCheck(using: qrService, against: keys)
    }
}

private func performScanCheck(using scanner: any KeyScanning, against keys: [Key]) async -> KeyResult {
    var verified: String?
    do {
        let value = try await scanner.scan { candidate in
            guard Key.matchingKeyExists(keys: keys, unhashedId: candidate) else { return false }
            verified = candidate
            return true
        }
        return value == verified ? .success : .failure
    } catch ScanError.userCanceled {
        return .cancelled
    } catch ScanError.invalidKey {
        return .failure
    } catch {
        return .failure
    }
}
