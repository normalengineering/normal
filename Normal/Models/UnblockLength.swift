import Foundation

enum UnblockLength: Equatable, Hashable, Sendable {
    case timed(TimedUnblockDuration)
    case permanent
}
