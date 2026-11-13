import SwiftUI

enum BlockStatus: Sendable, Equatable {
    case all
    case some
    case none

    var shortLabel: String {
        switch self {
        case .all: "Blocked"
        case .some: "Partial"
        case .none: "Unblocked"
        }
    }

    var title: String {
        switch self {
        case .all: "All Selected Apps Blocked"
        case .some: "Partially Blocked"
        case .none: "No Active Blocks"
        }
    }

    var color: Color {
        switch self {
        case .all: .green
        case .some: .orange
        case .none: .red
        }
    }

    var icon: String {
        switch self {
        case .all: "checkmark.shield.fill"
        case .some: "exclamationmark.shield.fill"
        case .none: "shield.slash"
        }
    }
}

extension BlockStatus {
    func canUnblockAll(timedUnblockActive: Bool) -> Bool {
        self != .none && !timedUnblockActive
    }

    func showsGroupTimedUnblock(timedUnblockActive: Bool) -> Bool {
        timedUnblockActive && self != .all
    }

    func canUnblockGroup(timedUnblockActive: Bool) -> Bool {
        self != .none && !showsGroupTimedUnblock(timedUnblockActive: timedUnblockActive)
    }
}

enum AuthorizationState: Sendable, Equatable {
    case authorized
    case notAuthorized
}
