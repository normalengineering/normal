import SwiftUI

enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Opacity {
        static let subtle: CGFloat = 0.10
        static let muted: CGFloat = 0.12
        static let scrim: CGFloat = 0.50
        static let dim: CGFloat = 0.60
    }

    enum Size {
        static let chipHeight: CGFloat = 34
        static let avatar: CGFloat = 48
        static let iconWell: CGFloat = 28
    }
}
