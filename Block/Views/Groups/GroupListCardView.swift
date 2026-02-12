import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct GroupListCardView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(\.modelContext) private var modelContext

    let appGroup: AppGroup
    let displayLimit = 3

    @State private var authAction: (@MainActor () -> Void)?
    @State private var allowBypass = false

    private var blockStatus: BlockStatus {
        screenTimeService.blockStatus(selection: appGroup.selection)
    }

    var body: some View {
        CardView {
            Text(appGroup.name)
                .font(.headline)
            HStack {
                groupIconView
                Spacer()
                Circle()
                    .fill(blockStatus.color)
                    .frame(width: 10, height: 10)
            }
        }
        .contextMenu {
            if blockStatus != .all {
                Button {
                    allowBypass = true
                    authAction = {
                        screenTimeService.addToShields(selection: appGroup.selection)
                    }
                } label: {
                    Label("Block", systemImage: "lock")
                }
            }

            if blockStatus != .none {
                Button {
                    allowBypass = false
                    authAction = {
                        screenTimeService.removeFromShields(selection: appGroup.selection)
                    }
                } label: {
                    Label("Unblock", systemImage: "lock.open")
                }
            }

            Button(role: .destructive) {
                modelContext.delete(appGroup)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .keySelect(action: $authAction, allowBypass: allowBypass)
    }

    private var groupIconView: some View {
        let allTokens = allTokensFromSelection(selection: appGroup.selection)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 24))], spacing: 8) {
            SelectionIconsView(tokens: allTokens)
        }
    }
}
