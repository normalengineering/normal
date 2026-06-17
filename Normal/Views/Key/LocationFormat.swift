import Foundation

enum LocationFormat {
    static func distance(meters: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }
}
