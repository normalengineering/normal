import Foundation
import Observation

@Observable
final class QRService {
    static let shared = QRService()

    enum ScanResult: Sendable, Equatable {
        case none
        case valid
        case invalid
    }

    private(set) var isScanning = false
    private(set) var scanResult: ScanResult = .none

    private var continuation: CheckedContinuation<String, Error>?
    private var validator: ((String) -> Bool)?

    private static let badgeDisplayDelay: Duration = .seconds(0.8)

    private init() {}

    func scan() async throws -> String {
        try await scan(validate: nil)
    }

    func scan(validate: ((String) -> Bool)?) async throws -> String {
        guard !isScanning else { throw ScanError.alreadyScanning }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.validator = validate
            self.scanResult = .none
            self.isScanning = true
        }
    }

    func handleScan(_ value: String) {
        guard let validator else {
            continuation?.resume(returning: value)
            cleanup()
            return
        }

        if validator(value) {
            scanResult = .valid
            Task { @MainActor in
                try? await Task.sleep(for: Self.badgeDisplayDelay)
                continuation?.resume(returning: value)
                cleanup()
            }
        } else {
            scanResult = .invalid
            Task { @MainActor in
                try? await Task.sleep(for: Self.badgeDisplayDelay)
                scanResult = .none
            }
        }
    }

    func cancel() {
        continuation?.resume(throwing: ScanError.userCanceled)
        cleanup()
    }

    private func cleanup() {
        continuation = nil
        validator = nil
        scanResult = .none
        isScanning = false
    }
}
