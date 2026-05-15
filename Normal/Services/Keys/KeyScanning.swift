import Foundation

protocol KeyScanning: AnyObject {
    func scan(validate: ((String) -> Bool)?) async throws -> String
}

extension NFCService: KeyScanning {}
extension QRService: KeyScanning {}
