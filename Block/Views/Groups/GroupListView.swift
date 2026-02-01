import FamilyControls
import SwiftData
import SwiftUI

struct GroupListView: View {
    @Query private var appGroups: [AppGroup]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(appGroups) {
                    appGroup in GroupListCardView(appGroup: appGroup
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
