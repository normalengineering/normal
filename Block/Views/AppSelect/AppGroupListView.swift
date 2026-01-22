import FamilyControls
import SwiftData
import SwiftUI

struct AppGroupListView: View {
    @Query private var appGroups: [AppGroup]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(appGroups) {
                    appGroup in AppGroupListCardView(appGroup: appGroup
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
