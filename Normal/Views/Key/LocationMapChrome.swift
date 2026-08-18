import MapKit
import SwiftUI

extension View {
    func locationMapChrome(kind: LocationRadiusKind, scope: Namespace.ID) -> some View {
        self
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {}
            .overlay(kind.fieldColor.opacity(0).allowsHitTesting(false))
            .overlay(alignment: .bottomTrailing) {
                MapUserLocationButton(scope: scope)
                    .buttonBorderShape(.circle)
                    .padding(DS.Spacing.md)
            }
    }
}
