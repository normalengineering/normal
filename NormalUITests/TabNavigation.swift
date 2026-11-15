import XCTest

extension XCUIApplication {
    func mainTab(_ label: String) -> XCUIElement {
        guard UIDevice.current.userInterfaceIdiom == .pad, #available(iOS 18.0, *) else {
            return tabBars.buttons[label]
        }
        return buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}
