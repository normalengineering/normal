import SwiftData
import SwiftUI

struct AppSelectView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(\.modelContext) private var modelContext

    @Query private var appGroups: [AppGroup]

    @State private var isShowingSheet = false
    @State private var showPopover = false
    @State private var selectedGroupForMenu: AppGroup?

    var body: some View {
        NavigationStack {
            List(appGroups) { group in
                HStack {
                    Text(group.name)
                    Spacer()
                }
                .contextMenu {
                    Button(role: .destructive) {
                        modelContext.delete(group)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("App Groups")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isShowingSheet.toggle() }) {
                        Label("Add Group", systemImage: "plus")
                    }
                    .sheet(isPresented: $isShowingSheet) {
                        CreateAppGroupSheet()
                    }
                }
            }
        }
    }
}
