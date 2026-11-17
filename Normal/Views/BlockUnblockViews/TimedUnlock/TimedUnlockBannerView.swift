import SwiftUI

struct TimedUnblockBannerView: View {
    @Environment(TimedUnblockService.self) private var timedUnblockService

    @Binding var authAction: ProtectedAction?
    let onBlockAllNow: () -> Void

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

                    CardActionButton(
                        title: "Block All Now",
                        systemImage: "lock.fill",
                        prominent: false,
                        tint: .orange
                    ) {
                        authAction = .tighten { onBlockAllNow() }
                    }
                    .accessibilityIdentifier("home.blockAllNow")
                }
            }
        }
    }
}
