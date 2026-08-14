import Foundation

/// Decides which entries of a status list stay visible when the user has opted to
/// hide whatever is currently blocked. Generic over the item so the rules can be
/// tested without Screen Time tokens, which cannot be built outside the system.
struct BlockedItemVisibility {
    let hideBlocked: Bool

    func visible<Item>(_ items: [Item], isBlocked: (Item) -> Bool) -> [Item] {
        guard hideBlocked else { return items }
        return items.filter { !isBlocked($0) }
    }

    func hiddenCount<Item>(_ items: [Item], isBlocked: (Item) -> Bool) -> Int {
        guard hideBlocked else { return 0 }
        return items.filter(isBlocked).count
    }
}
