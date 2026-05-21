import Foundation

@MainActor
@Observable
final class AppReviewService {
    private let defaults: UserDefaults
    private let minDaysBetweenPrompts: TimeInterval = .days(120)
    private let minSuccessfulUnblocks = 3
    private let postEventDelay: Duration = .seconds(1.5)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func recordUnblockEvent(prompt: @escaping @MainActor () -> Void, now: Date = .now) {
        let count = defaults.integer(forKey: Key.successfulUnblocks) + 1
        defaults.set(count, forKey: Key.successfulUnblocks)

        guard count >= minSuccessfulUnblocks else { return }
        if let last = defaults.object(forKey: Key.lastRequestedDate) as? Date,
           now.timeIntervalSince(last) < minDaysBetweenPrompts
        {
            return
        }
        defaults.set(now, forKey: Key.lastRequestedDate)
        Task { @MainActor in
            do {
                try await Task.sleep(for: postEventDelay)
                prompt()
            } catch {}
        }
    }

    private enum Key {
        static let lastRequestedDate = "appReview.lastRequestedDate"
        static let successfulUnblocks = "appReview.successfulUnblocks"
    }
}
