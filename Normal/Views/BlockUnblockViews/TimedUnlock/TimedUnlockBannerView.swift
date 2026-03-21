import FamilyControls
import SwiftUI

struct TimedUnblockBannerView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService

    let selection: FamilyActivitySelection

    @State private var authAction: (@MainActor () -> Void)?

    var body: some View {
        if let endDate = timedUnblockService.mainUnblockEndDate, endDate > .now {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.title2)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Timed Unblock Active")
                                .font(.headline)

                            Text(timerInterval: .now ... endDate, countsDown: true)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        authAction = {
                            timedUnblockService.cancelMain(
                                selection: selection,
                                screenTimeService: screenTimeService
                            )
                        }
                    } label: {
                        Label("Block All Now", systemImage: "lock.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
            .keySelect(action: $authAction, allowBypass: true)
        }
    }
}
