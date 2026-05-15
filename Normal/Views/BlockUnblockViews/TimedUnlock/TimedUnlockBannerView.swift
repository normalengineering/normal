import FamilyControls
import SwiftData
import SwiftUI

struct TimedUnblockBannerView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Query private var allSettings: [Settings]

    let selection: FamilyActivitySelection

    @State private var authAction: (@MainActor () -> Void)?

    private var settings: Settings { allSettings.unwrapped }

    var body: some View {
        if let endDate = timedUnblockService.mainUnblockEndDate, endDate > .now {
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "timer")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: DS.Spacing.xs - 2) {
                            Text("Timed Unblock Active").font(.headline)
                            Text(timerInterval: .now ... endDate, countsDown: true)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        authAction = {
                            timedUnblockService.cancelMain(
                                selection: selection,
                                screenTimeService: screenTimeService,
                                preventAppDelete: settings.blockAllPreventsAppDelete
                            )
                        }
                    } label: {
                        Label("Block All Now", systemImage: "lock.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
            .keySelect(action: $authAction, allowBypass: true)
        }
    }
}
