import Foundation

enum AppIcons {
    static var groups: String {
        if #available(iOS 26, *) {
            "app.shadow"
        } else {
            "square.fill.on.square.fill"
        }
    }
}
