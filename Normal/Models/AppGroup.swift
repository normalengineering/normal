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

    init(id: UUID = UUID(), name: String, selection: FamilyActivitySelection, sortIndex: Int = 0, customDomains: [String] = []) {
        self.id = id
        self.name = name
        self.selection = selection
        lastUpdated = .now
        self.sortIndex = sortIndex
        self.customDomains = customDomains
    }

    func deleteCascading(keys: [Key], from context: ModelContext) {
        for key in keys where key.groupID == id {
            context.delete(key)
        }
        context.delete(self)
    }
}
