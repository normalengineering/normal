import StoreKit
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(AppReviewService.self) private var appReviewService
    @Environment(\.requestReview) private var requestReview

    @Query private var selectedApps: [SelectedApps]
    @Query private var keys: [Key]
    @Query private var allSettings: [Settings]

    @State private var authAction: (@MainActor () -> Void)?
    @State private var allowBypass = false
    @State private var showTimedUnblockSheet = false

    private var mainSelection: SelectedApps? { selectedApps.first }
    private var settings: Settings { allSettings.unwrapped }

    private func customDomains(for selection: SelectedApps) -> [String] {
        settings.enableCustomDomains ? selection.customDomains : []
    }

    var body: some View {
        NavigationStack {
            List {
                if let mainSelection, !mainSelection.selection.isEmpty || UITestSupport.isActive {
                    TimedUnblockBannerView(
                        selection: mainSelection.selection,
                        customDomains: mainSelection.customDomains,
                        authAction: $authAction,
                        allowBypass: $allowBypass
                    )
                    MainBlockButtonView(
                        mainSelection: mainSelection,
                        authAction: $authAction,
                        allowBypass: $allowBypass,
                        onBlock: { blockMain(mainSelection) },
                        onUnblock: { unblockMain(mainSelection) }
                    )
                    BlockStatusView(mainSelection: mainSelection)
                    AppDeleteToggleView()
                } else {
                    Section {
                        Text("Please select apps to block in the selection tab.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .protectedAction($authAction, allowBypass: allowBypass, defaultKeyType: settings.defaultKeyType)
            .sheet(isPresented: $showTimedUnblockSheet) { timedUnblockSheet }
            .navigationTitle("Home")
            .settingsToolbar()
        }
    }

    @ViewBuilder
    private var timedUnblockSheet: some View {
        if let mainSelection {
            TimedUnblockSheet(
                title: "Unblock All",
                durations: settings.unblockDurations,
                initialDuration: settings.defaultDuration,
                onTimedUnblock: { duration in
                    try timedUnblockService.startMain(
                        duration: duration,
                        mainSelection: mainSelection,
                        settings: settings,
                        screenTimeService: screenTimeService
                    )
                    recordUnblockForReview()
                },
                onPermanentUnblock: {
                    screenTimeService.removeShieldOnAll(
                        blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete
                    )
                    scheduleService.setScheduleOverride(true)
                    recordUnblockForReview()
                }
            )
        }
    }

    private func blockMain(_ selection: SelectedApps) {
        BlockActions.blockAll(
            mainSelection: selection,
            settings: settings,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService,
            scheduleService: scheduleService
        )
    }

    private func unblockMain(_ selection: SelectedApps) {
        if let duration = settings.defaultDuration {
            do {
                try timedUnblockService.startMain(
                    duration: duration,
                    mainSelection: selection,
                    settings: settings,
                    screenTimeService: screenTimeService
                )
                recordUnblockForReview()
            } catch {}
        } else {
            showTimedUnblockSheet = true
        }
    }

    private func recordUnblockForReview() {
        appReviewService.recordUnblockEvent { requestReview() }
    }
}
