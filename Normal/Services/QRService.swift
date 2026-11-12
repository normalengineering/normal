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
    private(set) var lastScanCodeKind: ScanCodeKind?

    private var continuation: CheckedContinuation<String, Error>?
    private var validator: ((String) -> Bool)?
    private var scanID = UUID()

    private static let badgeDisplayDelay: Duration = .seconds(0.6)

    init() {}

    func scan() async throws -> String {
        try await scan(validate: nil)
    }

    func scan(validate: ((String) -> Bool)?) async throws -> String {
        if UITestSupport.isActive {
            if let validate, !validate(UITestSupport.stubScanValue) {
                throw ScanError.invalidKey
            }
            return UITestSupport.stubScanValue
        }
        guard !isScanning else { throw ScanError.alreadyScanning }

        return try await withCheckedThrowingContinuation { continuation in
            self.scanID = UUID()
            self.continuation = continuation
            self.validator = validate
            self.scanResult = .none
            self.lastScanCodeKind = nil
            self.isScanning = true
        }
    }

    func handleScan(_ value: String, kind: ScanCodeKind) {
        lastScanCodeKind = kind
        guard let validator else {
            continuation?.resume(returning: value)
            cleanup()
            return
        }

        if validator(value) {
            scanResult = .valid
            let scan = scanID
            Task { @MainActor in
                try? await Task.sleep(for: Self.badgeDisplayDelay)
                guard scan == scanID, let continuation else { return }
                continuation.resume(returning: value)
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
