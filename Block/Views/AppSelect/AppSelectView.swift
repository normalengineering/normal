import SwiftUI
import SwiftData

struct AppSelectView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    
    @Environment(\.modelContext) private var modelContext
    
    @Query private var appGroups: [AppGroup]
    
    var messageText = "Create app groups to organize apps you want to block. Apps can belong to multiple groups and will be blocked if any group containing them is active."
    
    
    var body: some View {
        NavigationStack {
            MessageView(message: messageText, color: Color.indigo)
                    List {
                        
                    }
                    .navigationTitle("Groups")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: { }) {
                                Label("Add Group", systemImage: "plus")
                            }
                        }
                    }
                }
    }
}
