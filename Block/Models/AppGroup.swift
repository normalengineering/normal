import FamilyControls
import Foundation
import SwiftData


@Model
final class AppGroup: Identifiable {
    var id: UUID
    var name: String
    var isBlocked: Bool
    var selection: FamilyActivitySelection
    
    init(name: String){
        self.id = UUID()
        self.name = name
        self.isBlocked = false
        self.selection = FamilyActivitySelection()
    }
}


