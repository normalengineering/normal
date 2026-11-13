import Foundation

enum UnblockLength: Equatable {
    case timed(TimedUnblockDuration)
    case permanent
}
