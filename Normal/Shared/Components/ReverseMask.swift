import SwiftUI

extension View {
    func reverseMask(@ViewBuilder _ mask: () -> some View) -> some View {
        self.mask {
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}
