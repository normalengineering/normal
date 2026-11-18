import FamilyControls
import Foundation
import SwiftData

@Model
final class AppGroup: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var lastUpdated: Date
    var sortIndex: Int = 0
    var customDomains: [String] = []
    var overridesDefaultDuration: Bool = false
    var defaultUnblockSeconds: Int?
    var overridesDefaultKey: Bool = false
    var defaultKeyType: KeyType?

    init(id: UUID = UUID(), name: String, selection: FamilyActivitySelection, sortIndex: Int = 0, customDomains: [String] = []) {
        self.id = id
        self.name = name
        self.selection = selection
        lastUpdated = .now
        self.sortIndex = sortIndex
        self.customDomains = customDomains
    }

    var durationOverride: DefaultOverride<TimedUnblockDuration> {
        get {
            guard overridesDefaultDuration else { return .appDefault }
            return defaultUnblockSeconds
                .flatMap(TimedUnblockDuration.init(validating:))
                .map(DefaultOverride.value) ?? .none
        }
        set {
            overridesDefaultDuration = newValue != .appDefault
            if case let .value(duration) = newValue {
                defaultUnblockSeconds = duration.seconds
            } else {
                defaultUnblockSeconds = nil
            }
        }
    }

    var keyOverride: DefaultOverride<KeyType> {
        get {
            guard overridesDefaultKey else { return .appDefault }
            return defaultKeyType.map(DefaultOverride.value) ?? .none
        }
        set {
            overridesDefaultKey = newValue != .appDefault
            if case let .value(keyType) = newValue {
                defaultKeyType = keyType
            } else {
                defaultKeyType = nil
            }
        }
    }

    func deleteCascading(keys: [Key], from context: ModelContext) {
        for key in keys where key.groupID == id {
            context.delete(key)
        }
        context.delete(self)
    }
}
