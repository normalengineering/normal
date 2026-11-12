import Foundation
import Observation

@MainActor
@Observable
final class UnlockRequestInbox {
    private struct Entry: Equatable {
        let request: UnblockRequest
        let postedAt: Date
    }

    static let lifetime: TimeInterval = 120

    private var entry: Entry?
    private let clock: () -> Date

    var pending: UnblockRequest? {
        entry?.request
    }

    init(clock: @escaping () -> Date = { .now }) {
        self.clock = clock
    }

    func post(_ request: UnblockRequest) {
        entry = Entry(request: request, postedAt: clock())
    }

    func take() -> UnblockRequest? {
        guard let entry else { return nil }
        self.entry = nil
        return clock().timeIntervalSince(entry.postedAt) <= Self.lifetime ? entry.request : nil
    }
}
