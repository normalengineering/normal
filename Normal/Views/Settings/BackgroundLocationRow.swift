import SwiftUI
import UIKit

struct BackgroundLocationRow: View {
    @Environment(LocationService.self) private var locationService

    var body: some View {
        if locationService.authorizationStatus != .authorizedAlways {
            Button("Allow Background Location") {
                if locationService.canRequestAlways {
                    locationService.requestAlwaysAuthorization()
                } else {
                    openSettings()
                }
            }
            .accessibilityIdentifier("settings.backgroundLocationButton")
        } else if locationService.accuracyAuthorization != .fullAccuracy {
            Button("Turn On Precise Location", action: openSettings)
                .accessibilityIdentifier("settings.preciseLocationButton")
        } else {
            LabeledContent("Background Location", value: "On")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
