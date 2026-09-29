import Foundation

enum CopyNaming {
    static func name(for original: String, existing: [String]) -> String {
        let taken = Set(existing)
        let first = String(localized: "\(original) Copy")
        guard taken.contains(first) else { return first }

        var number = 2
        while taken.contains(String(localized: "\(original) Copy \(number)")) {
            number += 1
        }
        return String(localized: "\(original) Copy \(number)")
    }
}
