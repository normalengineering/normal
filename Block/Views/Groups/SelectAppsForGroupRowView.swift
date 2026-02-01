import FamilyControls
import ManagedSettings
import SwiftUI

struct SelectAppForGroupRowView<T: Hashable>: View {
    let token: T
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let appToken = token as? ApplicationToken {
                    Label(appToken)
                } else if let webDomainToken = token as? WebDomainToken {
                    Label(webDomainToken)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
        }
    }
}
