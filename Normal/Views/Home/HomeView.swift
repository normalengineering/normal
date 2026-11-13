import StoreKit
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(AppReviewService.self) private var appReviewService
    @Environment(\.requestReview) private var requestReview

    @Query private var selectedApps: [SelectedApps]
    @Query private var keys: [Key]
    @Query private var allSettings: [Settings]

    @State private var authAction: ProtectedAction?
    @State private var durationGrant: UnblockGrant?

    private var mainSelection: SelectedApps? {
        selectedApps.first
    }

    private var settings: Settings {
        allSettings.unwrapped
    }

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
                        authAction: $authAction
                    )
                    MainBlockButtonView(
                        mainSelection: mainSelection,
                        authAction: $authAction,
                        onBlock: { blockMain(mainSelection) },
                        onUnblock: { unblockMain(mainSelection, proof: $0) }
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
            .protectedAction($authAction, defaultKeyType: settings.defaultKeyType)
            .sheet(item: $durationGrant) { grant in
                UnblockDurationSheet(grant: grant, onUnblock: recordUnblockForReview)
            }
            .navigationTitle("Home")
            .settingsToolbar()
        }
    }

    private func blockMain(_ selection: SelectedApps) {
        BlockActions.blockAll(
            mainSelection: selection,
            settings: settings,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService
        )
    }

    private func unblockMain(_ selection: SelectedApps, proof: KeyProof) {
        guard let grant = UnblockGrant(.all(selection), proof: proof) else { return }
        guard let duration = settings.defaultDuration else {
            durationGrant = grant
            return
        }
        do {
            try BlockActions.unblock(
                grant,
                for: .timed(duration),
                settings: settings,
                screenTimeService: screenTimeService,
                timedUnblockService: timedUnblockService
            )
            recordUnblockForReview()
        } catch {}
    }

    private func recordUnblockForReview() {
        appReviewService.recordUnblockEvent { requestReview() }
    }
}
