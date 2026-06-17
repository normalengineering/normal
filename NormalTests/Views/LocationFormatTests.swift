import Foundation
@testable import Normal
import Testing

struct LocationFormatTests {
    @Test func usesMetricUnitsForMetricLocale() {
        let label = LocationFormat.distance(meters: 1500, locale: Locale(identifier: "de_DE"))
        #expect(label.contains("km"))
        #expect(!label.contains("mi"))
    }

    @Test func usesImperialUnitsForUSLocale() {
        let label = LocationFormat.distance(meters: 1500, locale: Locale(identifier: "en_US"))
        #expect(label.contains("mi"))
        #expect(!label.contains("km"))
    }

    @Test func shortDistanceUsesMetersForMetricLocale() {
        let label = LocationFormat.distance(meters: 100, locale: Locale(identifier: "de_DE"))
        #expect(label.contains("m"))
        #expect(!label.contains("km"))
    }

    @Test func shortDistanceUsesFeetForUSLocale() {
        let label = LocationFormat.distance(meters: 100, locale: Locale(identifier: "en_US"))
        #expect(label.contains("ft"))
    }
}
