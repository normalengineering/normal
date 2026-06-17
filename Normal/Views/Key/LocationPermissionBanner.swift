import SwiftUI
import UIKit

struct LocationPermissionBanner: View {
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Label("Location permission needed", systemImage: "location.slash")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Enable location access in Settings to use your current spot. You can still pick anywhere on the map.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.bold())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }
}
