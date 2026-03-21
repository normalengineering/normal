import Foundation

enum KeyResult {
    case success
    case failure
    case cancelled
}

protocol KeyMethod {
    func checkKey() async -> KeyResult
}
