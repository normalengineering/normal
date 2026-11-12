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
    func allowsUnblockAll(mainTimedUnblockActive: Bool) -> Bool {
        self != .none && !mainTimedUnblockActive
    }

    func showsGroupTimedUnblock(groupTimedUnblockActive: Bool) -> Bool {
        groupTimedUnblockActive && self != .all
    }
}

enum AuthorizationState: Sendable, Equatable {
    case authorized
    case notAuthorized
}
