import Foundation

extension Settings {
    var editProtectionMode: EditProtectionMode {
        get {
            editProtectionRawValue.flatMap(EditProtectionMode.init(rawValue:)) ?? .requireKey
        }
        set {
            editProtectionRawValue = newValue.rawValue
        }
    }

    var editDurationOverride: DefaultOverride<TimedUnblockDuration> {
        get {
            guard overridesEditDefaultDuration else { return .appDefault }
            return
                editDefaultUnblockSeconds
                .flatMap(TimedUnblockDuration.init(validating:))
                .map(DefaultOverride.value) ?? .none
        }
        set {
            overridesEditDefaultDuration = newValue != .appDefault
            if case .value(let duration) = newValue {
                editDefaultUnblockSeconds = duration.seconds
            } else {
                editDefaultUnblockSeconds = nil
            }
        }
    }

    var editKeyOverride: DefaultOverride<KeyType> {
        get {
            guard overridesEditDefaultKey else { return .appDefault }
            return editDefaultKeyType.map(DefaultOverride.value) ?? .none
        }
        set {
            overridesEditDefaultKey = newValue != .appDefault
            if case .value(let keyType) = newValue {
                editDefaultKeyType = keyType
            } else {
                editDefaultKeyType = nil
            }
        }
    }

    var resolvedEditDefaultDuration: TimedUnblockDuration? {
        switch editDurationOverride {
        case .appDefault: defaultDuration
        case .none: nil
        case .value(let duration): unblockDurations.contains(duration) ? duration : nil
        }
    }

    var resolvedEditDefaultKeyType: KeyType? {
        switch editKeyOverride {
        case .appDefault: defaultKeyType
        case .none: nil
        case .value(let keyType): keyType
        }
    }
}
