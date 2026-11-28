import Foundation
import Observation

enum EditSessionState: Equatable {
    case blocked
    case timed(endDate: Date)
    case permanent
}

@MainActor
@Observable
final class EditSessionService {
    private static let modeKey = "editSession.mode"
    private static let endDateKey = "editSession.endDate"
    private static let timedValue = "timed"
    private static let permanentValue = "permanent"

    private let defaults: UserDefaults
    private let clock: () -> Date
    private nonisolated(unsafe) var expirationTask: Task<Void, Never>?

    private(set) var state: EditSessionState = .blocked

    init(
        defaults: UserDefaults = .standard,
        clock: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.clock = clock
        restoreState()
    }

    deinit {
        expirationTask?.cancel()
    }

    var isActive: Bool {
        switch state {
        case .blocked: false
        case .permanent: true
        case .timed(let endDate): endDate > clock()
        }
    }

    var endDate: Date? {
        guard case .timed(let endDate) = state, endDate > clock() else { return nil }
        return endDate
    }

    var isPermanent: Bool {
        state == .permanent
    }

    func unblock(for length: UnblockLength, proof: KeyProof) {
        guard proof.coversAllApps else { return }
        switch length {
        case .timed(let duration):
            let endDate = Self.endDate(of: duration, from: clock())
            state = .timed(endDate: endDate)
            defaults.set(Self.timedValue, forKey: Self.modeKey)
            defaults.set(endDate.timeIntervalSinceReferenceDate, forKey: Self.endDateKey)
            scheduleExpiration(at: endDate)
        case .permanent:
            cancelExpiration()
            state = .permanent
            defaults.set(Self.permanentValue, forKey: Self.modeKey)
            defaults.removeObject(forKey: Self.endDateKey)
        }
    }

    func grantEmergencyAccess() {
        cancelExpiration()
        state = .permanent
        defaults.set(Self.permanentValue, forKey: Self.modeKey)
        defaults.removeObject(forKey: Self.endDateKey)
    }

    func block() {
        cancelExpiration()
        state = .blocked
        defaults.removeObject(forKey: Self.modeKey)
        defaults.removeObject(forKey: Self.endDateKey)
    }

    func refresh() {
        switch state {
        case .timed(let endDate) where endDate <= clock():
            block()
        case .timed(let endDate):
            scheduleExpiration(at: endDate)
        case .blocked, .permanent:
            break
        }
    }

    static func hasUsableGlobalKey(
        in keys: [Key],
        availableKeyTypes: [KeyType] = KeyType.availableOnDevice
    ) -> Bool {
        let globalTypes = keys.filter(\.isGlobal).map(\.type)
        return !KeyType.selectable(registered: globalTypes, onDevice: availableKeyTypes).isEmpty
    }

    func isEditingBlocked(
        mode: EditProtectionMode,
        keys: [Key],
        activeShieldCount: Int,
        allowWhenNoKeys: Bool = false,
        availableKeyTypes: [KeyType] = KeyType.availableOnDevice
    ) -> Bool {
        switch mode {
        case .requireKey:
            if Self.hasUsableGlobalKey(in: keys, availableKeyTypes: availableKeyTypes) {
                return !isActive
            }
            return !keys.isEmpty && activeShieldCount > 0
        case .unblockAll:
            return activeShieldCount > 0 && (!allowWhenNoKeys || !keys.isEmpty)
        }
    }

    func requiresKeyToChangeMode(
        from current: EditProtectionMode,
        to target: EditProtectionMode,
        keys: [Key],
        activeShieldCount: Int = 0,
        availableKeyTypes: [KeyType] = KeyType.availableOnDevice
    ) -> Bool {
        guard current == .requireKey, target == .unblockAll else { return false }
        guard Key.hasGlobalKey(in: keys), !isActive else { return false }
        return Self.hasUsableGlobalKey(in: keys, availableKeyTypes: availableKeyTypes) || activeShieldCount > 0
    }

    private func restoreState() {
        switch defaults.string(forKey: Self.modeKey) {
        case Self.permanentValue:
            state = .permanent
        case Self.timedValue:
            let timestamp = defaults.double(forKey: Self.endDateKey)
            let endDate = Date(timeIntervalSinceReferenceDate: timestamp)
            if endDate > clock() {
                state = .timed(endDate: endDate)
                scheduleExpiration(at: endDate)
            } else {
                block()
            }
        default:
            state = .blocked
        }
    }

    private func scheduleExpiration(at endDate: Date) {
        cancelExpiration()
        let remaining = endDate.timeIntervalSince(clock())
        guard remaining > 0 else {
            block()
            return
        }
        expirationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let left = endDate.timeIntervalSince(self.clock())
                guard left > 0 else { break }
                try? await Task.sleep(for: .seconds(left))
            }
            guard !Task.isCancelled, let self else { return }
            self.block()
        }
    }

    private func cancelExpiration() {
        expirationTask?.cancel()
        expirationTask = nil
    }

    private static func endDate(of duration: TimedUnblockDuration, from start: Date) -> Date {
        let end = start.addingTimeInterval(duration.timeInterval).timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: end.rounded(.down))
    }
}
