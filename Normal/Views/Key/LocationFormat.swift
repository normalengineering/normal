import Foundation

enum LocationFormat {
    static func distance(meters: Double) -> String {
        meters < 1000 ? "\(Int(meters)) m" : String(format: "%.1f km", meters / 1000)
    }
}
