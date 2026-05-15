import Foundation

struct NFCKeyMethod: KeyMethod {
    let nfcService: any KeyScanning
    let keys: [Key]

    init(nfcService: any KeyScanning, keys: [Key]) {
        self.nfcService = nfcService
        self.keys = keys
    }

    func checkKey() async -> KeyResult {
        await performScanCheck(using: nfcService, against: keys)
    }
}

struct QRKeyMethod: KeyMethod {
    let qrService: any KeyScanning
    let keys: [Key]

    init(qrService: any KeyScanning, keys: [Key]) {
        self.qrService = qrService
        self.keys = keys
    }

    func checkKey() async -> KeyResult {
        await performScanCheck(using: qrService, against: keys)
    }
}

private func performScanCheck(using scanner: any KeyScanning, against keys: [Key]) async -> KeyResult {
    do {
        _ = try await scanner.scan { Key.matchingKeyExists(keys: keys, unhashedId: $0) }
        return .success
    } catch ScanError.userCanceled {
        return .cancelled
    } catch ScanError.invalidKey {
        return .failure
    } catch {
        return .failure
    }
}
