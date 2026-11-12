import SwiftUI
import UIKit

struct BackgroundLocationRow: View {
    @Environment(LocationService.self) private var locationService

    var body: some View {
        if locationService.authorizationStatus == .authorizedAlways {
            LabeledContent("Background Location", value: "On")
        } else {
            Button("Allow Background Location") {
                if locationService.canRequestAlways {
                    locationService.requestAlwaysAuthorization()
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .accessibilityIdentifier("settings.backgroundLocationButton")
        }
    }
}
