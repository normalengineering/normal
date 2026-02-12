import SwiftData
import SwiftUI

struct GroupsView: View {
    @State private var isShowingSheet = false
    @Query private var appGroups: [AppGroup]

    var body: some View {
        NavigationStack {
            ListView(items: appGroups) { appGroup in
                GroupListCardView(appGroup: appGroup)
            }
            .navigationTitle("App Groups")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isShowingSheet.toggle() }) {
                        Label("Add Group", systemImage: "plus")
                    }
                    .sheet(isPresented: $isShowingSheet) {
                        CreateGroupSheet()
                    }
                }
            }
        }
    }
}
