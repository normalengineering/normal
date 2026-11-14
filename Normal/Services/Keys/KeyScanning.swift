import Foundation

protocol KeyScanning: AnyObject {
    func scan(validate: ((String) -> Bool)?) async throws -> String
}

protocol CancellableKeyScanning: KeyScanning {
    var isScanning: Bool { get }
    func cancel()
}

extension NFCService: CancellableKeyScanning {}
extension QRService: CancellableKeyScanning {}
