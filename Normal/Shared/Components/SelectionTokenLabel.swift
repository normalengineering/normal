import FamilyControls
import ManagedSettings
import SwiftUI

struct SelectionTokenLabel: View {
    let kind: SelectedTokenKind

    var body: some View {
        switch kind {
        case .application(let token): Label(token)
        case .webDomain(let token): Label(token)
        case .category(let token): Label(token)
        }
    }
}
