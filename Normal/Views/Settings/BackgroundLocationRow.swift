import SwiftUI
import UIKit

struct BackgroundLocationRow: View {
    @Environment(LocationService.self) private var locationService

    private var status: String? {
        if locationService.authorizationStatus != .authorizedAlways {
            return "Off"
        }
        if locationService.accuracyAuthorization != .fullAccuracy {
            return "Precise Off"
        }
        return nil
    }

    private var opensSettings: Bool {
        locationService.authorizationStatus == .authorizedAlways || !locationService.canRequestAlways
    }

    var body: some View {
        if let status {
            Button(action: allow) {
                LabeledContent("Background Location", value: status)
            }
            .accessibilityHint(opensSettings ? "Opens Settings" : "")
            .accessibilityIdentifier("settings.backgroundLocation")
        } else {
            LabeledContent("Background Location", value: "On")
                .accessibilityIdentifier("settings.backgroundLocation")
        }
    }

    private func allow() {
        if opensSettings {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            locationService.requestAlwaysAuthorization()
        }
    }
}
