import SwiftData
import SwiftUI

struct KeysView: View {
    @State private var isShowingSheet = false
    @Query private var keys: [Key]

    var body: some View {
        NavigationStack {
            ListView(items: keys) {
                key in
                KeyListCardView(key: key)
            }
            .navigationTitle("Keys")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        isShowingSheet.toggle()
                        print(keys)
                    }) {
                        Label("Add Key", systemImage: "plus")
                    }
                    .sheet(isPresented: $isShowingSheet) {
                        CreateKeySheet()
                    }
                }
            }
        }
    }
}
