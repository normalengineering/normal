import SwiftUI

struct MainBlockButtonView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService

    let mainSelection: SelectedApps

    @State private var authAction: (@MainActor () -> Void)?
    @State private var allowBypass: Bool = false
    @State private var showTimedUnblockSheet = false

    private var blockStatus: BlockStatus {
        screenTimeService.blockStatus(selection: mainSelection.selection)
    }

    var body: some View {
        Section {
            if blockStatus != .all && !timedUnblockService.isMainUnblockActive {
                Button {
                    allowBypass = true
                    authAction = {
                        screenTimeService.applyShieldOnAll(selection: mainSelection.selection)
                    }
                } label: {
                    HStack {
                        Label("Block All", systemImage: "lock.fill")
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }

            if blockStatus != .none && !timedUnblockService.isMainUnblockActive {
                Button {
                    allowBypass = false
                    authAction = {
                        showTimedUnblockSheet = true
                    }
                } label: {
                    HStack {
                        Label("Unblock", systemImage: "lock.open.fill")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .keySelect(action: $authAction, allowBypass: allowBypass)
        .sheet(isPresented: $showTimedUnblockSheet) {
            TimedUnblockSheet(
                title: "Unblock All",
                onTimedUnblock: { duration in
                    try timedUnblockService.startMain(
                        duration: duration,
                        selection: mainSelection.selection,
                        screenTimeService: screenTimeService
                    )
                },
                onPermanentUnblock: {
                    screenTimeService.removeShieldOnAll()
                }
            )
        }
    }
}
