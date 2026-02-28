// TimedUnlock.swift
import Foundation
import SwiftData

enum UnlockDuration: CaseIterable, Identifiable {
    case tenMinutes
    case thirtyMinutes
    case oneHour
    case fourHours
    case indefinite

    var id: Self { self }

    var label: String {
        switch self {
        case .tenMinutes: "10 minutes"
        case .thirtyMinutes: "30 minutes"
        case .oneHour: "1 hour"
        case .fourHours: "4 hours"
        case .indefinite: "Indefinitely"
        }
    }

    var icon: String {
        switch self {
        case .tenMinutes: "10.circle"
        case .thirtyMinutes: "30.circle"
        case .oneHour: "1.circle"
        case .fourHours: "4.circle"
        case .indefinite: "infinity"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .tenMinutes: 10 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        case .fourHours: 4 * 60 * 60
        case .indefinite: nil
        }
    }
}

@Model
final class TimedUnlock {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date.now >= expiresAt
    }

    init(duration: UnlockDuration) {
        id = UUID()
        startedAt = .now
        expiresAt = duration.seconds.map { Date.now.addingTimeInterval($0) }
    }
}
