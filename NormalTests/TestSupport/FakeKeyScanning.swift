import Foundation
@testable import Normal

final class FakeKeyScanning: KeyScanning, @unchecked Sendable {
    enum Outcome {
        case acceptAny
        case acceptMatching
        case rejectInvalid
        case cancel
        case throwInvalidKey
        case throwGeneric
    }

    var outcome: Outcome
    var rawValue: String
    private(set) var validatorReceived: ((String) -> Bool)?

    init(outcome: Outcome = .acceptAny, rawValue: String = "tag-123") {
        self.outcome = outcome
        self.rawValue = rawValue
    }

    func scan(validate: ((String) -> Bool)?) async throws -> String {
        validatorReceived = validate
        switch outcome {
        case .acceptAny:
            return rawValue
        case .acceptMatching:
            guard let validate, validate(rawValue) else {
                throw ScanError.invalidKey
            }
            return rawValue
        case .rejectInvalid:
            _ = validate?(rawValue)
            throw ScanError.invalidKey
        case .cancel:
            throw ScanError.userCanceled
        case .throwInvalidKey:
            throw ScanError.invalidKey
        case .throwGeneric:
            throw ScanError.systemError(NSError(domain: "test", code: 0))
        }
    }
}
