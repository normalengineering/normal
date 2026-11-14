import Foundation
@testable import Normal

final class ControlledScanner: CancellableKeyScanning {
    private(set) var isScanning = false
    private(set) var scanCount = 0
    private var continuation: CheckedContinuation<String, Error>?
    private var validator: ((String) -> Bool)?

    func scan(validate: ((String) -> Bool)?) async throws -> String {
        guard !isScanning else { throw ScanError.alreadyScanning }
        scanCount += 1
        isScanning = true
        validator = validate
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func present(_ value: String) {
        guard let validator, validator(value) else { return }
        finish(.success(value))
    }

    func reject() {
        finish(.failure(ScanError.invalidKey))
    }

    func cancel() {
        finish(.failure(ScanError.userCanceled))
    }

    private func finish(_ result: Result<String, Error>) {
        let pending = continuation
        continuation = nil
        validator = nil
        isScanning = false
        pending?.resume(with: result)
    }
}
