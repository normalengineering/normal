import FamilyControls
import SwiftData
import SwiftUI

struct AppGroupListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appGroups: [AppGroup]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(appGroups) {
                    group in
                    CardView(primaryText: group.name, secondaryText: "\(group.selection.applicationTokens.count)") {
                        Image(systemName: "person.3.fill")
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(group)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
