import SwiftData
import SwiftUI

struct KeysView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var keys: [Key]
    @State private var isShowingSheet = false

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0 && !keys.isEmpty
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Keys")
                .settingsToolbar()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { isShowingSheet.toggle() } label: {
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

    @ViewBuilder
    private var content: some View {
        if keys.isEmpty {
            ContentUnavailableView {
                Label("No Keys", systemImage: "key.viewfinder")
            } description: {
                Text(noKeysDescription)
            } actions: {
                Button("Add Key") { isShowingSheet = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ListView(items: keys) { key in
                KeyListCardView(key: key)
            }
            .safeAreaInset(edge: .bottom) {
                if isBlocked {
                    FooterMessage(text: "Unblock all apps to manage keys.")
                }
            }
        }
    }

    private var noKeysDescription: LocalizedStringKey {
        KeyType.nfc.isAvailableOnDevice
            ? "Keys are required to block and unblock apps. Add an NFC tag or QR code to get started."
            : "Keys are required to block and unblock apps. Add a QR code to get started."
    }
}
