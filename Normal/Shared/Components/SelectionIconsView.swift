import FamilyControls
import ManagedSettings
import SwiftUI

struct SelectionIconsView: View {
    let tokens: [AnyHashable]

    var body: some View {
        let sorted = tokens.sortedStably
        ForEach(sorted, id: \.self) { token in
            Group {
                if let appToken = token as? ApplicationToken {
                    Label(appToken)
                } else if let webDomainToken = token as? WebDomainToken {
                    Label(webDomainToken)
                } else if let categoryToken = token as? ActivityCategoryToken {
                    Label(categoryToken)
                }
            }
            .labelStyle(.iconOnly)
        }
    }
}
