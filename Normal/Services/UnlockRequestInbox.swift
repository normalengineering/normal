import Foundation
import Observation

@MainActor
@Observable
final class UnlockRequestInbox {
    struct Request: Equatable {
        let token: UUID
        let groupID: UUID?
        let duration: UnlockDurationRequest
        let keyType: KeyType?
        let postedAt: Date
    }

    static let lifetime: TimeInterval = 120

    private(set) var pending: Request?
    private let clock: () -> Date

    init(clock: @escaping () -> Date = { .now }) {
        self.clock = clock
    }

    func post(groupID: UUID?, duration: UnlockDurationRequest, keyType: KeyType?) {
        pending = Request(token: UUID(), groupID: groupID, duration: duration, keyType: keyType, postedAt: clock())
    }

    func take() -> Request? {
        guard let request = pending else { return nil }
        pending = nil
        return clock().timeIntervalSince(request.postedAt) <= Self.lifetime ? request : nil
    }
}
