import Foundation

nonisolated enum TagDecision: Equatable, Sendable {
    case proceed(hexId: String)
    case reject(ScanError.NFCError)

    static func decide(
        hexId: String?,
        hasRandomIdentifier: Bool,
        hasMRTDApplication: Bool
    ) -> TagDecision {
        guard let hexId else { return .reject(.unsupportedTag) }
        if hasRandomIdentifier { return .reject(.unstableIdentifier) }
        if hasMRTDApplication { return .reject(.unstableIdentifier) }
        return .proceed(hexId: hexId)
    }
}
