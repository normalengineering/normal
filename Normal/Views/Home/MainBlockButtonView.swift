import SwiftData
import SwiftUI

struct MainBlockButtonView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Query private var allSettings: [Settings]
    @Query private var keys: [Key]

    let mainSelection: SelectedApps
    @Binding var authAction: ProtectedAction?
    let onBlock: @MainActor () -> Void
    let onUnblock: @MainActor (KeyProof) -> Void

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var customDomains: [String] {
        settings.enableCustomDomains ? mainSelection.customDomains : []
    }

    private var blockStatus: BlockStatus {
        screenTimeService.blockStatus(selection: mainSelection.selection, customDomains: customDomains)
    }

    private var canShowBlock: Bool {
        blockStatus != .all && !timedUnblockService.isMainUnblockActive
    }

    private var canShowUnblock: Bool {
        blockStatus.canUnblockAll(timedUnblockActive: timedUnblockService.isMainUnblockActive)
    }

    private var hasGlobalKey: Bool {
        Key.hasGlobalKey(in: keys)
    }

    var body: some View {
        Section {
            if canShowBlock {
                blockRow
            }
            if canShowUnblock {
                unblockRow
            }
        } footer: {
            if canShowBlock, !hasGlobalKey {
                Text("Add a key in the Keys tab before blocking apps.")
            }
        }
    }

    private var blockRow: some View {
        Button {
            authAction = .tighten { onBlock() }
        } label: {
            HStack {
                Label("Block All", systemImage: "lock.fill")
                    .foregroundStyle(.blue)
                Spacer()
            }
        }
        .accessibilityIdentifier("home.blockAll")
        .padding(.vertical, DS.Spacing.sm)
        .disabled(!hasGlobalKey)
    }

    private var unblockRow: some View {
        Button {
            authAction = .weaken { onUnblock($0) }
        } label: {
            HStack {
                Label("Unblock All", systemImage: "lock.open.fill")
                    .foregroundStyle(.red)
                Spacer()
            }
        }
        .accessibilityIdentifier("home.unblockAll")
        .padding(.vertical, DS.Spacing.sm)
    }
}
