import SwiftData
import SwiftUI

struct KeysView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var keys: [Key]
    @State private var isShowingSheet = false

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0 && !keys.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if keys.isEmpty {
                    ContentUnavailableView {
                        Label("No Keys", systemImage: "key.viewfinder")
                    } description: {
                        Text(KeyType.nfc.isAvailableOnDevice
                            ? "Keys are required to block and unblock apps. Add an NFC tag or QR code to get started."
                            : "Keys are required to block and unblock apps. Add a QR code to get started.")
                    } actions: {
                        Button {
                            isShowingSheet = true
                        } label: {
                            Text("Add Key")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
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
                }
            }
            .navigationTitle("Keys")
            .settingsToolbar()
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
