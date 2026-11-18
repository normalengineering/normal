extension Settings {
    func defaultDuration(for group: AppGroup?) -> TimedUnblockDuration? {
        switch group?.durationOverride ?? .appDefault {
        case .appDefault: defaultDuration
        case .none: nil
        case let .value(duration): unblockDurations.contains(duration) ? duration : nil
        }
    }

    func defaultKeyType(for group: AppGroup?) -> KeyType? {
        switch group?.keyOverride ?? .appDefault {
        case .appDefault: defaultKeyType
        case .none: nil
        case let .value(keyType): keyType
        }
    }
}
