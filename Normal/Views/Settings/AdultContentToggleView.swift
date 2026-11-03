import SwiftUI

struct AdultContentToggleView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    let defaultKeyType: KeyType?

    var body: some View {
        KeyProtectedToggle(
            title: "Block Adult Websites",
            isOn: screenTimeService.isAdultContentBlocked,
            defaultKeyType: defaultKeyType
        ) { screenTimeService.setAdultContentBlocked($0) }
            .accessibilityIdentifier("settings.blockAdultContentToggle")
    }
}
