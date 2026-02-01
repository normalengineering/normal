import SwiftData
import SwiftUI

struct GroupsView: View {
    @State private var isShowingSheet = false
    @State private var selectedGroupForMenu: AppGroup?

    var body: some View {
        NavigationStack {
            GroupListView()
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
