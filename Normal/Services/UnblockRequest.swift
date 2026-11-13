import Foundation

nonisolated struct UnblockRequest: Equatable, Sendable {
    let groupID: UUID?
    let duration: UnlockDurationRequest
    let keyType: KeyType?
}
