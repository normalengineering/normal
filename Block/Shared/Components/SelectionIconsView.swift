import FamilyControls
import ManagedSettings
import SwiftUI

struct SelectionIconsView: View {
    let tokens: [AnyHashable]

    var body: some View {
        ForEach(tokens, id: \.self) { token in
            Group {
                if let appToken = token as? ApplicationToken {
                    Label(appToken)
                } else if let categoryToken = token as? ActivityCategoryToken {
                    Label(categoryToken)
                } else if let webDomainToken = token as? WebDomainToken {
                    Label(webDomainToken)
                }
            }
            .labelStyle(.iconOnly)
        }
    }
}
