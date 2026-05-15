import SwiftData
import SwiftUI

struct MainBlockButtonView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Query private var allSettings: [Settings]

    let mainSelection: SelectedApps

    @State private var authAction: (@MainActor () -> Void)?
    @State private var allowBypass: Bool = false
    @State private var showTimedUnblockSheet = false

    private var settings: Settings { allSettings.unwrapped }

    private var blockStatus: BlockStatus {
        screenTimeService.blockStatus(selection: mainSelection.selection)
    }

    private var canShowBlock: Bool {
        blockStatus != .all && !timedUnblockService.isMainUnblockActive
    }

    private var canShowUnblock: Bool {
        blockStatus != .none && !timedUnblockService.isMainUnblockActive
    }

    var body: some View {
        Section {
            if canShowBlock { blockRow }
            if canShowUnblock { unblockRow }
        }
        .protectedAction($authAction, allowBypass: allowBypass, defaultKeyType: settings.defaultKeyType)
        .sheet(isPresented: $showTimedUnblockSheet) { timedUnblockSheet }
    }

    private var blockRow: some View {
        Button {
            allowBypass = true
            authAction = {
                screenTimeService.applyShieldOnAll(
                    selection: mainSelection.selection,
                    preventAppDelete: settings.blockAllPreventsAppDelete
                )
            }
        } label: {
            HStack {
                Label("Block All", systemImage: "lock.fill")
                    .foregroundStyle(.blue)
                Spacer()
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private var unblockRow: some View {
        Button {
            allowBypass = false
            authAction = {
                if let duration = settings.defaultUnblockDuration {
                    try? timedUnblockService.startMain(
                        duration: duration,
                        selection: mainSelection.selection,
                        screenTimeService: screenTimeService,
                        allowAppDelete: settings.blockAllPreventsAppDelete
                    )
                } else {
                    showTimedUnblockSheet = true
                }
            }
        } label: {
            HStack {
                Label("Unblock All", systemImage: "lock.open.fill")
                    .foregroundStyle(.red)
                Spacer()
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private var timedUnblockSheet: some View {
        TimedUnblockSheet(
            title: "Unblock All",
            onTimedUnblock: { duration in
                try timedUnblockService.startMain(
                    duration: duration,
                    selection: mainSelection.selection,
                    screenTimeService: screenTimeService,
                    allowAppDelete: settings.blockAllPreventsAppDelete
                )
            },
            onPermanentUnblock: {
                screenTimeService.removeShieldOnAll(
                    allowAppDelete: settings.blockAllPreventsAppDelete
                )
            }
        )
    }
}
