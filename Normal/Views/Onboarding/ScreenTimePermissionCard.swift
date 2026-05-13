import SwiftUI

struct ScreenTimePermissionCard: View {
    var onGrant: () -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Label("Screen Time Permission", systemImage: "hourglass")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Normal uses Screen Time to block and unblock apps. You can grant this now or later when you first block an app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button(action: onGrant) {
                        Text("Grant Permission")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)

                    if let onSkip {
                        Button("Skip", action: onSkip)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .glassEffect(in: .rect(cornerRadius: 20))
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
