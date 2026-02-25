import SwiftData
import SwiftUI

struct KeysView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService
    
    @Query private var keys: [Key]
    @State private var isShowingSheet = false
    
    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    var body: some View {
        NavigationStack {
            ListView(items: keys) { key in
                KeyListCardView(key: key)
            }
            .safeAreaInset(edge: .bottom) {
                if isBlocked {
                    Text("Unblock all apps to manage keys.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .navigationTitle("Keys")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isShowingSheet.toggle() }) {
                        Label("Add Key", systemImage: "plus")
                    }
                    .disabled(isBlocked)
                    .sheet(isPresented: $isShowingSheet) {
                        KeyFormSheet()
                    }
                }
            }
        }
    }
}
