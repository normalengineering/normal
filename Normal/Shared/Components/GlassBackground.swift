import SwiftUI

extension View {
    @ViewBuilder
    func glassCardBackground(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}
