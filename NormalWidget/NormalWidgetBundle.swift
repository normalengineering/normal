import SwiftUI
import WidgetKit

@main
struct NormalWidgetBundle: WidgetBundle {
    var body: some Widget {
        GroupUnlockWidget()
        TimedUnblockLiveActivity()
        if #available(iOS 18.0, *) {
            BlockAllControl()
            BlockGroupControl()
        }
    }
}
