import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct GroupListCardView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(\.modelContext) private var modelContext
    @Query private var appGroups: [AppGroup]

    let appGroup: AppGroup
    let displayLimit = 3

    var body: some View {
        let blockStaus = screenTimeService.blockStatus(selection: appGroup.selection)
        CardView {
            Text(appGroup.name)
                .font(.headline)
            HStack {
                groupIconView
                Spacer()
                Circle()
                    .fill(blockStaus.color)
                    .frame(width: 10, height: 10)
            }
        }
        .contextMenu {
            if blockStaus != .all {
                lockButton
            }
            if blockStaus != .none {
                unlockButton
            }
            Button(role: .destructive) {
                modelContext.delete(appGroup)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var lockButton: some View {
        return Button(role: .confirm) {
            screenTimeService.addToShields(selection: appGroup.selection)
        } label: {
            Label("Block", systemImage: "lock")
        }
    }

    private var unlockButton: some View {
        return Button(role: .confirm) {
            screenTimeService.removeFromShields(selection: appGroup.selection)
        } label: {
            Label("Unblock", systemImage: "lock.open")
        }
    }

    private var groupIconView: some View {
        let allTokens = allTokensFromSelection(selection: appGroup.selection)

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 24))], spacing: 8) {
            SelectionIconsView(tokens: allTokens)
        }
    }
}
